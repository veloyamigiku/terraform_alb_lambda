import json
import logging

logger = logging.getLogger('lambda_logger')
logger.setLevel(logging.INFO)

def handler(event, context):
    
    logger.info(
        'function = %s, version = %s, request_id = %s',
        context.function_name,
        context.function_version,
        context.aws_request_id)
    
    logger.info('event = %s', event)

    body = json.loads(event['body'])
    last_name = body['last_name']
    first_name = body['first_name']

    return {
        "statusCode": 200,
        "statusDescription": "200 OK",
        "isBase64Encoded": False,
        "headers": {
            "Content-Type": "text/html"
        },
        "body": f'{first_name} {last_name}!!'
    }
