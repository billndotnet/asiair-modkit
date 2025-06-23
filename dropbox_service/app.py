import json
import os
import threading
from functools import wraps

from flask import Flask, redirect, request, session, url_for, render_template_string
import dropbox
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

app = Flask(__name__)
app.secret_key = 'change-me'

CONFIG_PATH = os.path.expanduser('~/.dropbox_service_config.json')
MONITORED_DIR = '/mnt/asiair'

def load_config():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, 'r') as f:
            return json.load(f)
    return {}

def save_config(data):
    with open(CONFIG_PATH, 'w') as f:
        json.dump(data, f)

config = load_config()


def requires_token(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        if 'access_token' not in config:
            return redirect(url_for('index'))
        return f(*args, **kwargs)
    return wrapper


class UploadHandler(FileSystemEventHandler):
    def __init__(self, dbx):
        self.dbx = dbx

    def on_created(self, event):
        if event.is_directory:
            return
        dest_path = os.path.relpath(event.src_path, MONITORED_DIR)
        with open(event.src_path, 'rb') as f:
            self.dbx.files_upload(f.read(), f'/{dest_path}', mode=dropbox.files.WriteMode.overwrite)


def start_watcher():
    dbx = dropbox.Dropbox(config['access_token'])
    event_handler = UploadHandler(dbx)
    observer = Observer()
    observer.schedule(event_handler, MONITORED_DIR, recursive=True)
    observer.daemon = True
    observer.start()
    return observer

watcher = None

@app.route('/')
def index():
    authorized = 'access_token' in config
    monitoring = watcher is not None and watcher.is_alive()
    return render_template_string(
        """
        <h1>Dropbox Uploader</h1>
        {% if not authorized %}
            <a href='{{ url_for('login') }}'>Connect to Dropbox</a>
        {% else %}
            <p>Account connected.</p>
            <form action='{{ url_for('toggle') }}' method='post'>
                <button type='submit'>{{ 'Stop' if monitoring else 'Start' }} Monitoring</button>
            </form>
        {% endif %}
        """,
        authorized=authorized,
        monitoring=monitoring,
    )

@app.route('/login')
def login():
    auth_flow = dropbox.oauth.DropboxOAuth2Flow(
        os.environ.get('DROPBOX_APP_KEY'),
        os.environ.get('DROPBOX_APP_SECRET'),
        url_for('oauth_callback', _external=True),
        session,
        'dropbox-auth-csrf-token',
    )
    authorize_url = auth_flow.start()
    session['auth_flow'] = auth_flow.serialize()
    return redirect(authorize_url)

@app.route('/oauth2/callback')
def oauth_callback():
    if 'auth_flow' not in session:
        return redirect(url_for('index'))
    auth_flow = dropbox.oauth.DropboxOAuth2Flow.deserialize(session['auth_flow'])
    try:
        token = auth_flow.finish(request.args)
    except Exception as e:
        return f'Auth failed: {e}'
    config['access_token'] = token.access_token
    save_config(config)
    return redirect(url_for('index'))

@app.route('/toggle', methods=['POST'])
@requires_token
def toggle():
    global watcher
    if watcher is None or not watcher.is_alive():
        watcher = start_watcher()
    else:
        watcher.stop()
        watcher.join()
        watcher = None
    return redirect(url_for('index'))


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
