import json

def lambda_handler(event, context):
    print("Hello, World!")
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"message": "Hello, World!"}),
    }
