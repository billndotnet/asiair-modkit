import os
from functools import wraps

from flask import Flask, redirect, request, session, url_for, render_template_string
import dropbox
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

CONFIG_PATH = os.path.expanduser('~/.dropbox_service.conf')
DEFAULT_CONFIG = {
    'MONITORED_DIR': '/mnt/asiair',
    'PORT': '8080',
    'SECRET_KEY': 'change-me',
    'DROPBOX_APP_KEY': '',
    'DROPBOX_APP_SECRET': '',
}

def load_config():
    config = DEFAULT_CONFIG.copy()
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    k, v = line.split('=', 1)
                    config[k.strip()] = v.strip()
    else:
        with open(CONFIG_PATH, 'w') as f:
            for k, v in config.items():
                f.write(f"{k}={v}\n")
    return config

def save_config(cfg):
    with open(CONFIG_PATH, 'w') as f:
        for k, v in cfg.items():
            f.write(f"{k}={v}\n")

config = load_config()

app = Flask(__name__)
app.secret_key = config.get('SECRET_KEY', 'change-me')
MONITORED_DIR = config.get('MONITORED_DIR', '/mnt/asiair')


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
        <p><a href='{{ url_for('settings') }}'>Settings</a></p>
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


@app.route('/settings', methods=['GET', 'POST'])
def settings():
    message = ''
    if request.method == 'POST':
        for key in ['MONITORED_DIR', 'DROPBOX_APP_KEY', 'DROPBOX_APP_SECRET', 'PORT']:
            if key in request.form:
                config[key] = request.form[key]
        save_config(config)
        global MONITORED_DIR
        MONITORED_DIR = config.get('MONITORED_DIR')
        message = 'Saved. Restart service if port or secret key changed.'
    return render_template_string(
        """
        <h1>Settings</h1>
        <form method='post'>
            <label>Monitored Directory: <input name='MONITORED_DIR' value='{{ cfg.MONITORED_DIR }}'></label><br>
            <label>Dropbox App Key: <input name='DROPBOX_APP_KEY' value='{{ cfg.DROPBOX_APP_KEY }}'></label><br>
            <label>Dropbox App Secret: <input name='DROPBOX_APP_SECRET' value='{{ cfg.DROPBOX_APP_SECRET }}'></label><br>
            <label>Port: <input name='PORT' value='{{ cfg.PORT }}'></label><br>
            <button type='submit'>Save</button>
        </form>
        <p>{{ message }}</p>
        <p><a href='{{ url_for('index') }}'>Back</a></p>
        """,
        cfg=config,
        message=message,
    )

@app.route('/login')
def login():
    auth_flow = dropbox.oauth.DropboxOAuth2Flow(
        config.get('DROPBOX_APP_KEY') or os.environ.get('DROPBOX_APP_KEY'),
        config.get('DROPBOX_APP_SECRET') or os.environ.get('DROPBOX_APP_SECRET'),
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
    app.run(host='0.0.0.0', port=int(config.get('PORT', '8080')))
