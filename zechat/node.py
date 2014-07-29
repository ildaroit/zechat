import logging
from contextlib import contextmanager

logger = logging.getLogger(__name__)


class Node(object):

    def __init__(self):
        self.client_map = {}

    @contextmanager
    def register_client(self, ws):
        self.client_map[ws.id] = ws
        try:
            yield
        finally:
            del self.client_map[ws.id]

_node = Node()


class Transport(object):

    def __init__(self, ws):
        self.ws = ws

    def messages(self):
        while True:
            msg = self.ws.receive()
            if msg is None:  # disconnect
                break

            if not msg:  # ping?
                continue

            logger.debug("message: %s", msg)
            yield msg

    def run(self):
        with _node.register_client(self.ws):
            for msg in self.messages():
                for client in _node.client_map.values():
                    client.send(msg)


def transport(ws):
    Transport(ws).run()


def init_app(app):
    from flask.ext.uwsgi_websocket import GeventWebSocket
    websocket = GeventWebSocket(app)
    websocket.route('/ws/transport')(transport)
