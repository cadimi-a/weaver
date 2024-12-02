import unittest
import json

class TestApiGWTemplate(unittest.TestCase):
    def setUp(self):
        # Load the API Gateway template
        with open('/app/api_gw_mapping.template', 'r') as file:
            template_content = file.readlines()

        self.template_body = ''.join(template_content)

    def test_template_valid(self):
        """Test if the template is valid"""
        try:
            json_data = json.loads(self.template_body)
            self.assertIsInstance(json_data, dict)
        except json.JSONDecodeError as e:
            self.fail(f"Template is invalid: {e}")

    def test_template_invalid(self):
        """Test if the template fails when it is invalid"""
        invalid_template = self.template_body.replace('{', '}')

        with self.assertRaises(json.JSONDecodeError):
            json.loads(invalid_template)

if __name__ == '__main__':
    unittest.main()
