import unittest
import json
import importlib.util

def load_event(file_path):
    with open(file_path, 'r') as f:
        return json.load(f)

class TestLambdaFunction(unittest.TestCase):
    def setUp(self):
        # Load the Lambda
        lambda_path = '/app/lambda/main.py'

        spec = importlib.util.spec_from_file_location('main', lambda_path)
        self.main = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.main)

        self.valid_event_from_dynamodb_stream = load_event('/app/test/sample/valid_event.json')
        self.invalid_event_from_dynamodb_stream = load_event('/app/test/sample/invalid_event.json')


    def test_lambda_success(self):
        """Valid event test Lambda runs successfully"""
        response = self.main.lambda_handler(
            self.valid_event_from_dynamodb_stream,
            None
        )
        self.assertEqual(
            response['statusCode'],
            200
        )

    def test_lambda_fail(self):
        """Invalid event test Lambda fails on purpose"""
        response = self.main.lambda_handler(
            self.invalid_event_from_dynamodb_stream,
            None
        )
        self.assertEqual(
            response['statusCode'],
            500
        )

if __name__ == '__main__':
    unittest.main()