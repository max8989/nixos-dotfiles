#!@python@
"""Select local images and return JSON, preserving literal filenames."""
import json
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, Gtk

dialog = Gtk.FileChooserDialog(title="Import wallpapers", action=Gtk.FileChooserAction.OPEN)
dialog.add_buttons("Cancel", Gtk.ResponseType.CANCEL, "Import", Gtk.ResponseType.ACCEPT)
dialog.set_select_multiple(True)
dialog.set_local_only(True)
dialog.set_current_folder(sys.argv[1])
dialog.set_default_response(Gtk.ResponseType.ACCEPT)


# Always treat Escape as cancelling the import, including from the search field.
def cancel_on_escape(widget, event):
    if event.keyval == Gdk.KEY_Escape:
        widget.response(Gtk.ResponseType.CANCEL)
        return True
    return False


dialog.connect("key-press-event", cancel_on_escape)
images = Gtk.FileFilter()
images.set_name("Images (PNG, JPEG, WebP, BMP)")
for mime in ("image/png", "image/jpeg", "image/webp", "image/bmp", "image/x-ms-bmp"):
    images.add_mime_type(mime)
for extension in ("png", "jpg", "jpeg", "webp", "bmp"):
    images.add_pattern("*." + extension)
    images.add_pattern("*." + extension.upper())
dialog.add_filter(images)
response = dialog.run()
paths = dialog.get_filenames() if response == Gtk.ResponseType.ACCEPT else []
folder = dialog.get_current_folder()
dialog.destroy()
print(json.dumps({"paths": paths, "folder": folder}))
