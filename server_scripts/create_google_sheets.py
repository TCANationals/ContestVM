# This script creates multiple Google sheets based on the contestant_id_list.txt file
# It will also create URL shortcuts to the sheets in the users drive if provided

# To run, you must install the following:
#   pip install --upgrade google-api-python-client google-auth-httplib2 google-auth-oauthlib swinlnk


from __future__ import print_function

import os.path

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from swinlnk.swinlnk import SWinLnk


# If modifying these scopes, delete the file token.json.
SCOPES = [
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/spreadsheets',
]
SHORTCUT_ROOT = './scuts/'

def create_sheets(SHEET_SVC, DRIVE_SVC):
    lines = []
    with open('./contestant_id_list.txt') as f:
        lines = f.read().splitlines()
    for user_id in lines:
        if user_id and user_id != '':
            sheet_id = create_sheet(f'TCA 2022 - Web Scraping {user_id}', SHEET_SVC, DRIVE_SVC)
            swl = SWinLnk()
            swl.create_lnk(f"https://docs.google.com/spreadsheets/d/{sheet_id}/edit", f'{SHORTCUT_ROOT}/{user_id}.lnk')

def create_sheet(title, SHEET_SVC, DRIVE_SVC):
    spreadsheet = {
        'properties': {
            'title': title
        }
    }
    spreadsheet = SHEET_SVC.spreadsheets().create(body=spreadsheet,
                                            fields='spreadsheetId').execute()
    fileId = spreadsheet.get('spreadsheetId')
    permission = {
        'type': 'anyone',
        'role': 'writer',
    }
    DRIVE_SVC.permissions().create(fileId=fileId, body=permission).execute()
    #print('Spreadsheet ID: {0}'.format(fileId))
    #print(f"https://docs.google.com/spreadsheets/d/{fileId}/edit")
    return fileId

def main():
    """Shows basic usage of the Drive v3 API.
    Prints the names and ids of the first 10 files the user has access to.
    """
    creds = None
    # The file token.json stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                'credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    try:
        DRIVE_SVC = build('drive', 'v3', credentials=creds)
        SHEET_SVC = build('sheets', 'v4', credentials=creds)

        # # Call the Drive v3 API
        # results = drive_service.files().list(
        #     pageSize=10, fields="nextPageToken, files(id, name)").execute()
        # items = results.get('files', [])

        # if not items:
        #     print('No files found.')
        #     return
        # print('Files:')
        # for item in items:
        #     print(u'{0} ({1})'.format(item['name'], item['id']))
        create_sheets(SHEET_SVC, DRIVE_SVC)
    except HttpError as error:
        # TODO(developer) - Handle errors from drive API.
        print(f'An error occurred: {error}')


if __name__ == '__main__':
    main()
