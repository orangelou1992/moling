import http.server, socketserver, threading, os

class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass

os.chdir('/home/louyz/.openclaw/workspace')
server = socketserver.TCPServer(('', 18888), Handler)
t = threading.Thread(target=lambda: server.handle_request)
t.start()
print('Ready on port 18888')
t.join(timeout=3)
