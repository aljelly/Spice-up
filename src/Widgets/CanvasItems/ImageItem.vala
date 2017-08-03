/*
* Copyright (c) 2016 Felipe Escoto (https://github.com/Philip-Scott/Spice-up)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Felipe Escoto <felescoto95@hotmail.com>
*/

public class Spice.ImageItem : Spice.CanvasItem {
    private ImageHandler image;

    const string IMAGE_STYLE_CSS = """
        .colored {
            background-color: transparent;
            background-image: url("%s");
            background-position: center;
            background-size: contain;
            background-repeat: no-repeat;
            border: none;
        }
    """;

    const string IMAGE_MISSING_CSS = """
        .colored {
           border: 4px dashed #000000;
           border-color: #c92e34;
        }""";

    public string extension {
        get {
            return image.image_extension;
        }
    }

    public string url {
        get {
            return image.url;
        }
    }

    public ImageItem (Canvas _canvas, Json.Object? _save_data = null) {
        Object (canvas: _canvas, save_data: _save_data);

        load_data ();
        style ();
    }

    public ImageItem.from_file (Canvas _canvas, File file) {
        Object (canvas: _canvas, save_data: null);

        this.image = new ImageHandler.from_file (file);
        connect_image ();
        style ();
    }

    protected override void load_item_data () {
        string? base64_image = null;

        if (save_data.has_member ("image-data")) {
            base64_image = save_data.get_string_member ("image-data");
        }

        if (base64_image != null && base64_image != "") {
            var extension = save_data.get_string_member ("image");
            image = new ImageHandler.from_data (extension, base64_image);
        } else {
            var tmp_uri = save_data.get_string_member ("image");
            image = new ImageHandler.from_file (File.new_for_uri (tmp_uri));
        }

        connect_image ();
    }

    protected override string serialise_item () {
        return """"type":"image", %s""".printf (image.serialize ());
    }

    public override void style () {
        if (image.valid) {
            Utils.set_style (this, IMAGE_STYLE_CSS.printf (image.url));
        } else {
            unstyle ();
        }
    }

    private void unstyle () {
         Utils.set_style (this, IMAGE_MISSING_CSS);
    }

    private void connect_image () {
        image.file_changed.connect (() => {
             unstyle ();
             style ();
        });
    }

    private class ImageHandler : Object {
        private static uint file_id = 0;
        const string FILENAME = "/spice-up-%s-img-%u.%s";

        public signal void file_changed ();

        private FileMonitor monitor;
        private bool file_changing = false;

        public bool valid = false;
        private string? base64_image = null;

        public string image_extension { get; private set; }

        private string url_ = "";
        public string url {
            get {
                return url_;
            } set {
                url_ = value;
                var file = File.new_for_path (value);
                monitor_file (file);
                valid = (file.query_exists () && Utils.is_valid_image (file));
                file_changed ();
            }
        }

        public ImageHandler.from_data (string _extension, string _base64_data) {
            image_extension = _extension != "" ? _extension : "png";
            base64_image = _base64_data;
            url = data_to_file (_base64_data);
        }

        public ImageHandler.from_file (File file) {
            image_extension = get_extension (file.get_basename ());
            data_from_filename (file.get_path ());
            url = data_to_file (base64_image);
        }

        public string serialize () {
            return """"image":"%s", "image-data":"%s" """.printf (image_extension, base64_image);
        }

        private void monitor_file (File file) {
            monitor = file.monitor (FileMonitorFlags.NONE, null);

            monitor.changed.connect ((src, dest, event) => {
                if (event == FileMonitorEvent.CHANGED) {
                    file_changing = true;
                } else if (event == FileMonitorEvent.CHANGES_DONE_HINT && file_changing) {
                    data_from_filename (url);
                    file_changed ();
                    file_changing = false;
                }
            });
        }

        private string get_extension (string filename) {
            var parts = filename.split (".");
            if (parts.length > 1) {
                return parts[parts.length - 1];
            } else {
                return "png";
            }
        }

        private void data_from_filename (string path) {
            base64_image = Spice.Services.FileManager.file_to_base64 (path);
        }

        private string data_to_file (string data) {
            var filename = Environment.get_tmp_dir () + FILENAME.printf (Environment.get_user_name (), file_id++, image_extension);
            Spice.Services.FileManager.base64_to_file (filename, data);

            return filename;
        }
    }
}
