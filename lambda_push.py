import json
import requests

def lambda_handler(event, context):
    # ServiceNow instance details
    instance_url = 'https://your_instance.service-now.com'
    username = 'your_username'
    password = 'your_password'

    # Parse the message from the SNS event
    for record in event['Records']:
        sns_message = json.loads(record['Sns']['Message'])
        # You can extract more details from the sns_message as needed

        # Prepare the payload for the ServiceNow event
        payload = {
            'source': 'AWS Health',
            'event_class': 'AWS Alert',
            'resource': sns_message.get('detail', {}).get('eventArn', 'Unknown'),
            'severity': '3',  # Change severity as needed
            'description': json.dumps(sns_message, indent=4),
            'node': 'AWS',  # Change node as needed
            'type': sns_message.get('detail-type', 'Unknown'),
        }

        # Send the request to ServiceNow to create an event
        response = requests.post(
            f'{instance_url}/api/now/table/em_event',
            auth=(username, password),
            headers={'Content-Type': 'application/json'},
            data=json.dumps(payload)
        )

        # Check the response
        if response.status_code == 201:
            print('Event created successfully:', response.json()['result']['sys_id'])
        else:
            print('Failed to create event:', response.status_code, response.text)

    return {
        'statusCode': 200,
        'body': json.dumps('Lambda function executed successfully!')
    }