import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "audio_buffer", Path(__file__).resolve().parents[1] / "lowlat_audio.py"
)
audio_buffer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio_buffer)


class BufferTests(unittest.TestCase):
    def test_small_buffer_is_enlarged(self):
        with patch.object(audio_buffer.os, "open", return_value=17), \
                patch.object(audio_buffer.os, "close") as close, \
                patch.object(audio_buffer.fcntl, "fcntl", side_effect=[16384, 32768]) as control:
            audio_buffer.configure_pipe()
            self.assertEqual(control.call_args_list[-1].args, (17, audio_buffer.F_SETPIPE_SZ, 32768))
            close.assert_called_once_with(17)

    def test_large_buffer_is_never_reduced(self):
        for size in [32768, 65536]:
            with self.subTest(size=size), \
                    patch.object(audio_buffer.os, "open", return_value=17), \
                    patch.object(audio_buffer.os, "close"), \
                    patch.object(audio_buffer.fcntl, "fcntl", return_value=size) as control:
                audio_buffer.configure_pipe()
                control.assert_called_once_with(17, audio_buffer.F_GETPIPE_SZ)

    def test_missing_audio_device_is_nonfatal(self):
        with patch.object(audio_buffer.os, "open", side_effect=OSError):
            audio_buffer.configure_pipe()

    def test_resize_failure_closes_descriptor(self):
        with patch.object(audio_buffer.os, "open", return_value=17), \
                patch.object(audio_buffer.os, "close") as close, \
                patch.object(audio_buffer.fcntl, "fcntl", side_effect=[16384, PermissionError]), \
                patch.object(audio_buffer.sys, "stderr"):
            audio_buffer.configure_pipe()
            close.assert_called_once_with(17)


if __name__ == "__main__":
    unittest.main()
