import pathlib
import unittest

from mywebapp.config import load_config


class ConfigTests(unittest.TestCase):
    def test_load_config_from_fixture(self) -> None:
        path = pathlib.Path(__file__).parent / "fixtures" / "config.ini"
        config = load_config(str(path))
        self.assertEqual(config.app_host, "127.0.0.1")
        self.assertEqual(config.app_port, 5000)
        self.assertEqual(config.db.name, "mywebapp")
        self.assertEqual(config.db.user, "mywebapp")


if __name__ == "__main__":
    unittest.main()

