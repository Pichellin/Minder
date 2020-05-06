
/*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
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
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;
using GLib;
using Gdk;

public class MinderClipboard {

  const string NODES_TARGET_NAME = "x-application/minder-nodes";
  static Atom  NODES_ATOM        = Atom.intern_static_string( NODES_TARGET_NAME );

  private static DrawArea?    da    = null;
  private static Array<Node>? nodes = null;
  private static Connections? conns = null;
  private static string?      text  = null;
  private static Pixbuf       image = null;

  enum Target {
    STRING,
    IMAGE,
    NODES
  }

  const TargetEntry[] text_target_list = {
    { "text/plain", 0, Target.STRING },
    { "STRING",     0, Target.STRING }
  };

  const TargetEntry[] image_target_list = {
    { "image/png", 0, Target.IMAGE }
  };

  const TargetEntry[] node_target_list = {
    { "text/plain",      0, Target.STRING },
    { "STRING",          0, Target.STRING },
    { "image/png",       0, Target.IMAGE },
    { NODES_TARGET_NAME, 0, Target.NODES }
  };

  public static void set_with_data( Clipboard clipboard, SelectionData selection_data, uint info, void* user_data_or_owner) {
    switch( info ) {
      case Target.STRING:
        debug( "String requested\n" );
        if( text != null ) {
          selection_data.set_text( text, -1 );
        } else if( (nodes != null) && (nodes.length == 1) ) {
          selection_data.set_text( nodes.index( 0 ).name.text, -1 );
        }
        break;
      case Target.IMAGE:
        debug ("Image requested\n");
        if( image != null ) {
          selection_data.set_pixbuf( image );
        } else if( (nodes != null) && (nodes.length == 1) && (nodes.index( 0 ).image != null) ) {
          selection_data.set_pixbuf( nodes.index( 0 ).image.get_pixbuf().copy() );
        }
        break;
      case Target.NODES:
        debug ("Nodes requested\n");
        stdout.printf( "Nodes requested, nodes: %u\n", ((nodes == null) ? 0 : nodes.length) );
        if( (nodes != null) && (nodes.length > 0) ) {
          var text = da.serialize_for_copy( nodes, conns );
          stdout.printf( "  text: %s\n", text );
          selection_data.@set( NODES_ATOM, 0, text.data );
        }
        break;
      default:
        debug ("Other data %u\n", info);
        break;
    }
  }

  /* Clears the class structure */
  public static void clear_data( Clipboard clipboard, void* user_data_or_owner ) {
    da    = null;
    nodes = null;
    conns = null;
    text  = null;
    image = null;
  }

  /* Copies the selected text to the clipboard */
  public static void copy_text( string txt ) {

    /* Store the data to copy */
    text = txt;

    /* Inform the clipboard */
    var clipboard = Clipboard.get_default( Gdk.Display.get_default() );
    clipboard.set_with_data( text_target_list, set_with_data, clear_data, null );

  }

  public static void copy_image( Pixbuf img ) {

    /* Store the data to copy */
    image = img;

    /* Inform the clipboard */
    var clipboard = Clipboard.get_default( Gdk.Display.get_default() );
    clipboard.set_with_data( image_target_list, set_with_data, clear_data, null );

  }

  /* Copies the current selected node list to the clipboard */
  public static void copy_nodes( DrawArea d ) {

    /* Store the data to copy */
    da = d;
    da.get_nodes_for_clipboard( out nodes, out conns );

    stdout.printf( "In copy_nodes, nodes: %u\n", nodes.length );

    /* Inform the clipboard */
    var clipboard = Gtk.Clipboard.get_default( Gdk.Display.get_default() );
    clipboard.set_with_data( node_target_list, set_with_data, clear_data, null );

  }

  /* Returns true if there are any nodes pasteable in the clipboard */
  public static bool node_pasteable() {
    var clipboard = Clipboard.get_default( Gdk.Display.get_default() );
    return( clipboard.wait_is_target_available( NODES_ATOM ) );
  }

  /* Called to paste current item in clipboard to the given DrawArea */
  public static void paste( DrawArea da, bool shift ) {

    var clipboard = Clipboard.get_default( Gdk.Display.get_default() );

    Atom[] targets;
    clipboard.wait_for_targets( out targets );

    Atom? nodes_atom = null;
    Atom? text_atom  = null;
    Atom? image_atom = null;

    /* Get the list of targets that we will support */
    foreach( var target in targets ) {
      stdout.printf( "target: %s\n", target.name() );
      switch( target.name() ) {
        case NODES_TARGET_NAME :  nodes_atom = target;  break;
        case "text/plain"      :  text_atom  = target;  break;
        case "image/png"       :  image_atom = target;  break;
      }
    }

    /* If we need to handle a node, do it here */
    if( nodes_atom != null ) {
      clipboard.request_contents( nodes_atom, (c, raw_data) => {
        var data = (string)raw_data.get_data();
        if( data == null ) return;
        da.paste_nodes( data, shift );
      });

    /* If we need to handle pasting text, do it here */
    } else if( image_atom != null ) {
      clipboard.request_contents( image_atom, (c, raw_data) => {
        var data = raw_data.get_pixbuf();
        if( data == null ) return;
        da.paste_image( data, shift );
      });

    /* If we need to handle pasting an image, do it here */
    } else if( text_atom != null ) {
      clipboard.request_contents( text_atom, (c, raw_data) => {
        var data = (string)raw_data.get_data();
        if( data == null ) return;
        da.paste_text( data, shift );
      });
    }

  }

}
