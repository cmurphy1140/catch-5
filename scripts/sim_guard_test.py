#!/usr/bin/env python3
"""Checks sim_guard's memory gate and lock without booting a simulator.
Run: python3 scripts/sim_guard_test.py"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import sim_guard as g  # noqa: E402


class MemoryGate(unittest.TestCase):
    def test_verdicts(self):
        cases = [  # (level, free %, refuses?)
            (1, 30, False), (1, 10, True),
            (2, 30, True), (2, None, True),
            (4, 90, True), (None, 30, False), (None, None, False),
        ]
        for level, free, refuses in cases:
            with self.subTest(level=level, free=free):
                self.assertEqual(g.memory_refusal(level, free) is not None, refuses)

    def test_watchdog_trips_once_on_critical(self):
        levels, calls = iter([2, 2, 4, 4]), []
        with g.pressure_watchdog(lambda: calls.append(1), interval=0.05,
                                 read_level=lambda: next(levels, 4)) as tripped:
            self.assertTrue(tripped.wait(2))
        self.assertEqual(calls, [1])

    def test_watchdog_stays_quiet_at_warning(self):
        calls = []
        with g.pressure_watchdog(lambda: calls.append(1), interval=0.05,
                                 read_level=lambda: 2) as tripped:
            self.assertFalse(tripped.wait(0.3))
        self.assertEqual(calls, [])


class Lock(unittest.TestCase):
    def setUp(self):
        self.path = os.path.join(tempfile.mkdtemp(), "sim_guard.lock")

    def _child(self, body):
        code = f"import sys,os,time; sys.path.insert(0, {HERE!r}); " \
               f"import sim_guard as g\nwith g.sim_lock({self.path!r}):\n    {body}"
        return subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, text=True)

    def test_second_job_waits_then_refuses(self):
        holder = self._child("print('held', flush=True); time.sleep(3)")
        self.assertEqual(holder.stdout.readline().strip(), "held")
        with self.assertRaises(g.Refused):
            with g.sim_lock(self.path, wait=0.5):
                pass
        holder.wait()

    def test_kill_9_releases_the_lock(self):
        crasher = self._child("print('held', flush=True); os.kill(os.getpid(), 9)")
        self.assertEqual(crasher.stdout.readline().strip(), "held")
        self.assertEqual(crasher.wait(), -9)
        with g.sim_lock(self.path, wait=1):
            pass


if __name__ == "__main__":
    unittest.main()
