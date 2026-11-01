import sys
from pathlib import Path
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'dragon-core'))
from secret_filter import redact, secret_spans, masked

class Secrets(unittest.TestCase):
    def test_types(self):
        for value, kind in [('DEPLOY_SECRET="two words"','variable'), ('DB_PASSWORD=abc','variable'),
                            ('FOO_KEY: abc','variable'), ('"FOO_KEY": "abc"','variable'), ('Bearer abc.def','bearer'),
                            ('https://alice:pass@host/path','url'), ('ghp_abcdefghijk','token'),
                            ('AKIA1234567890123456','token'), ('sk-abcdefghijkl','token'),
                            ('-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----','pem')]:
            with self.subTest(kind=kind):
                text,n=redact(value)
                self.assertEqual(text, '[oculto:'+kind+']');self.assertEqual(n,1)
                self.assertTrue(secret_spans(value));self.assertEqual(masked(value),('••••••••',True))
    def test_before_truncation_and_incomplete_pem(self):
        text,_=redact('x '*100+'-----BEGIN PRIVATE KEY-----\ncredential')
        self.assertNotIn('credential',text)
    def test_safe(self):
        for value in ['git status','https://example.com/documentation', '/home/user/project-name', '[oculto:variable]']:
            self.assertEqual(redact(value),(value,0))
    def test_structural_identifiers(self):
        for value in ["01a1947a-784c-7101-a525-1de1473cf14c", "a1"*32]:
            self.assertEqual(redact(value),(value,0))
    def test_multiple(self):
        self.assertEqual(redact('A_TOKEN=x B_SECRET=y')[1],2)
