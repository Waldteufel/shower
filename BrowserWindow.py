#!/usr/bin/python3

import html
from urllib.parse import urlparse

from PyQt5.QtWidgets import QApplication, QWidget, qApp, QVBoxLayout, QLineEdit, QLabel, QMainWindow, QShortcut, QProgressBar, QSizePolicy
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEnginePage, QWebEngineSettings
from PyQt5.QtGui import QIcon, QKeySequence
from PyQt5.QtCore import QUrl, Qt


class BrowserWindow(QMainWindow):

    def __init__(self, url='', windowType=QWebEnginePage.WebBrowserWindow):
        super().__init__()
        self.hoveredUrl = ''
        self.initUI(windowType)
        if url != '':
            self.cmdLine.setText(url)
            self.handleCommand()
        else:
            self.beginEnteringCommand(None)

    def beginEnteringCommand(self, cmd):
        self.cmdLine.show()
        self.cmdLine.setFocus(Qt.OtherFocusReason)
        if cmd is None:
            self.cmdLine.setText(self.webView.page().url().toDisplayString())
            self.cmdLine.selectAll()
        else:
            self.cmdLine.setText(cmd)

    def handleCommand(self):
        cmd = self.cmdLine.text()
        if cmd.startswith('?'):
            self.webView.page().load(QUrl('https://duckduckgo.com/?q=' + cmd[1:].strip()))
            self.cmdLine.hide()
        elif cmd.startswith('/'):
            self.webView.page().findText(cmd[1:].strip())
        else:
            url = urlparse(cmd)
            if url.scheme == '':
                url = url._replace(scheme='https')
            self.webView.page().load(QUrl(url.geturl()))
            self.cmdLine.hide()

    def linkHovered(self, url):
        self.hoveredUrl = url
        self.urlChanged()

    def urlChanged(self):
        if self.hoveredUrl != '':
            self.statusLine.setText('<i>{}</i>'.format(html.escape(self.hoveredUrl)))
        else:
            self.statusLine.setText(html.escape(self.webView.page().url().toDisplayString()))

    def titleChanged(self):
        title = self.webView.page().title()
        if title == '':
            self.setWindowTitle('shower')
        else:
            self.setWindowTitle('shower: ' + title)

    def addShortcut(self, key, handler):
        shortcut = QShortcut(QKeySequence(key), self)
        shortcut.activated.connect(handler)

    def initUI(self, windowType):
        vbox = QVBoxLayout()
        vbox.setContentsMargins(0, 0, 0, 0)
        vbox.setSpacing(0)

        self.webView = QWebEngineView()
        vbox.addWidget(self.webView)

        self.progressBar = QProgressBar()
        self.progressBar.setTextVisible(False)
        self.progressBar.hide()
        vbox.addWidget(self.progressBar)

        self.statusLine = QLabel()
        self.statusLine.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)
        self.statusLine.setTextFormat(Qt.RichText)
        vbox.addWidget(self.statusLine)

        self.cmdLine = QLineEdit()
        self.cmdLine.hide()
        vbox.addWidget(self.cmdLine)

        centralWidget = QWidget()
        centralWidget.setLayout(vbox)

        self.setCentralWidget(centralWidget)
        self.setWindowTitle('shower')

        self.cmdLine.returnPressed.connect(self.handleCommand)

        self.webView.page().linkHovered.connect(self.linkHovered)
        self.webView.page().urlChanged.connect(self.urlChanged)
        self.webView.page().titleChanged.connect(self.titleChanged)
        self.webView.page().loadProgress.connect(self.progressBar.setValue)
        self.webView.page().loadStarted.connect(self.progressBar.show)
        self.webView.page().loadFinished.connect(self.progressBar.hide)

        self.addShortcut("Alt+Left", lambda: self.webView.page().triggerAction(QWebEnginePage.Back))
        self.addShortcut("Alt+Right", lambda: self.webView.page().triggerAction(QWebEnginePage.Forward))
        self.addShortcut("Ctrl+R", lambda: self.webView.page().triggerAction(QWebEnginePage.Reload))
        self.addShortcut("Ctrl+Shift+R", lambda: self.webView.page().triggerAction(QWebEnginePage.ReloadAndBypassCache))
        self.addShortcut("Esc", lambda: self.webView.page().triggerAction(QWebEnginePage.Stop))
        self.addShortcut("Ctrl+W", lambda: self.close())
        self.addShortcut("Ctrl+L", lambda: self.beginEnteringCommand(None))
        self.addShortcut("Ctrl+K", lambda: self.beginEnteringCommand('? '))
