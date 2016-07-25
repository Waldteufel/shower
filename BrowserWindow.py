#!/usr/bin/python3

import html
from urllib.parse import urlparse

from PyQt5.QtWidgets import QWidget, QVBoxLayout, QHBoxLayout, QLineEdit, QLabel, QShortcut, QProgressBar, QSizePolicy, QMessageBox
from PyQt5.QtWebEngineWidgets import QWebEngineView, QWebEnginePage, QWebEngineSettings
from PyQt5.QtGui import QKeySequence
from PyQt5.QtCore import QUrl, Qt, pyqtSignal, pyqtSlot


class BrowserPage(QWebEnginePage):

    def __init__(self, window):
        super().__init__(window.webView)
        self.window = window

    def acceptNavigationRequest(self, url, navType, isMainFrame):
        allow = True

        if self.window.isLatent:
            if allow:
                self.window.isLatent = False
                self.window.show()
            else:
                self.window.deleteLater()

        if allow and isMainFrame:
            self.window.nextUrl = url
            self.window.urlChanged.emit()

        return allow

    def certificateError(self, error):
        if error.isOverridable():
            return QMessageBox.warning(self.window, 'Certificate warning', '<b>{}</b><br><br><i>{}</i><br><br>Override?'.format(html.escape(error.url().toDisplayString()), error.errorDescription()), QMessageBox.Yes | QMessageBox.No, QMessageBox.No) == QMessageBox.Yes
        else:
            QMessageBox.warning(self.window, 'Certificate warning', '<b>{}</b><br><br><i>{}</i>'.format(error.url(), error.errorDescription()))
            return False

    def createWindow(self, windowType):
        win = BrowserWindow(self.window.svc, isLatent=True)
        return win.webView.page()


class BrowserWindow(QWidget):

    urlChanged = pyqtSignal()

    def __init__(self, svc, url='', windowType=QWebEnginePage.WebBrowserWindow, isLatent=False):
        super().__init__()
        self.svc = svc
        self.hoveredUrl = ''
        self.isLatent = isLatent
        self.isLoading = False
        self.nextUrl = QUrl('')
        self.initUI(windowType)
        if url != '':
            self.cmdLine.setText(url)
            self.handleCommand()
        else:
            self.beginEnteringCommand(None)

    def beginEnteringCommand(self, cmd):
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
        elif cmd.startswith('/'):
            self.webView.page().findText(cmd[1:].strip())
        else:
            url = urlparse(cmd)
            if url.scheme == '':
                url = url._replace(scheme='https')
            self.webView.page().load(QUrl(url.geturl()))

    def toggleSource(self):
        url = self.webView.page().url().toDisplayString()
        if url == '': return
        prefix = 'view-source:'
        if url.startswith(prefix):
            url = url[len(prefix):]
        else:
            url = prefix + url
        self.webView.page().load(QUrl(url))

    @pyqtSlot(str)
    def onLinkHovered(self, url):
        self.hoveredUrl = url
        self.urlChanged.emit()

    def url(self):
        if self.isLoading:
            return self.nextUrl
        else:
            return self.webView.page().url()

    @pyqtSlot()
    def onUrlChanged(self):
        if self.hoveredUrl != '':
            self.urlLabel.setText('<span style="color: gray">{}</span>'.format(html.escape(self.hoveredUrl)))
        else:
            self.urlLabel.setText(html.escape(self.url().toDisplayString()))

    @pyqtSlot()
    def onTitleChanged(self):
        title = self.webView.page().title()
        if title == '':
            self.setWindowTitle('shower')
        else:
            self.setWindowTitle('shower: ' + title)

    def addShortcut(self, key, handler):
        shortcut = QShortcut(QKeySequence(key), self)
        shortcut.activated.connect(handler)
        return shortcut

    @pyqtSlot()
    def onLoadStarted(self):
        self.isLoading = True
        self.stopShortcut.setEnabled(True)
        self.progressLabel.setText('<span style="color: yellow">[ 0%]</span>')

    @pyqtSlot(int)
    def onLoadProgress(self, n):
        if n == 100:
            self.progressLabel.setText('<span style="color: green">[100]</span>'.format(n))
        else:
            self.progressLabel.setText('<span style="color: yellow">[{:2d}%]</span>'.format(n))

    @pyqtSlot()
    def onLoadFinished(self):
        self.isLoading = False
        self.stopShortcut.setEnabled(False)
        self.urlChanged.emit()

    def initUI(self, windowType):
        self.setStyleSheet("""
            #cmdLine, #bar, #bar > * { border: 0px; background: #070707; font-family: "Pro Font"; font-size: 10px; color: white; min-height: 17px }
        """)

        self.setWindowTitle('shower')
        self.setAttribute(Qt.WA_DeleteOnClose)

        vbox = QVBoxLayout()
        self.setLayout(vbox)
        vbox.setContentsMargins(0, 0, 0, 0)
        vbox.setSpacing(0)

        bar = QWidget()
        bar.setObjectName('bar')
        hbox = QHBoxLayout()
        hbox.setContentsMargins(2, 0, 0, 0)
        hbox.setSpacing(0)
        bar.setLayout(hbox)
        vbox.addWidget(bar)

        self.urlLabel = QLabel()
        self.urlLabel.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Preferred)
        self.urlLabel.setTextFormat(Qt.RichText)
        hbox.addWidget(self.urlLabel)
        hbox.setStretch(0, 1)

        self.progressLabel = QLabel()
        self.progressLabel.setTextFormat(Qt.RichText)
        hbox.addWidget(self.progressLabel)

        self.cmdLine = QLineEdit()
        self.cmdLine.setObjectName('cmdLine')
        vbox.addWidget(self.cmdLine)

        self.webView = QWebEngineView()
        self.webView.setPage(BrowserPage(self))
        vbox.addWidget(self.webView)

        self.cmdLine.returnPressed.connect(self.handleCommand)

        self.webView.page().linkHovered.connect(self.onLinkHovered)
        self.webView.page().urlChanged.connect(self.urlChanged)
        self.webView.page().titleChanged.connect(self.onTitleChanged)
        self.webView.page().loadProgress.connect(self.onLoadProgress)
        self.webView.page().loadStarted.connect(self.onLoadStarted)
        self.webView.page().loadFinished.connect(self.onLoadFinished)

        self.urlChanged.connect(self.onUrlChanged)

        self.addShortcut("Alt+Left", lambda: self.webView.page().triggerAction(QWebEnginePage.Back))
        self.addShortcut("Alt+Right", lambda: self.webView.page().triggerAction(QWebEnginePage.Forward))
        self.addShortcut("Ctrl+R", lambda: self.webView.page().triggerAction(QWebEnginePage.Reload))
        self.addShortcut("Ctrl+Shift+R", lambda: self.webView.page().triggerAction(QWebEnginePage.ReloadAndBypassCache))
        self.stopShortcut = self.addShortcut("Esc", lambda: self.webView.page().triggerAction(QWebEnginePage.Stop))
        self.addShortcut("Ctrl+W", lambda: self.close())
        self.addShortcut("Ctrl+L", lambda: self.beginEnteringCommand(None))
        self.addShortcut("Ctrl+K", lambda: self.beginEnteringCommand('? '))
        self.addShortcut("Ctrl+/", lambda: self.beginEnteringCommand('/ '))
        self.addShortcut("Ctrl+U", lambda: self.toggleSource())
