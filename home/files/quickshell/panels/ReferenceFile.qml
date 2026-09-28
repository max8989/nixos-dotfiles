pragma ComponentBehavior: Bound
import Quickshell.Io

FileView {
    property string sourcePath: ""
    signal ready
    path: sourcePath
    printErrors: false
    onLoaded: ready()
}
