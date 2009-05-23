
(*
 * Copyright (C) 2007-2009 The laby team
 * You have permission to copy, modify, and redistribute under the
 * terms of the GPL-3.0. For full license terms, see gpl-3.0.txt.
 *)

let log = Log.make ["gfx"]

let tile_size = 40

exception Error of F.t

type ressources =
    {
      void_p : GdkPixbuf.pixbuf;
      exit_p : GdkPixbuf.pixbuf;
      wall_p : GdkPixbuf.pixbuf;
      rock_p : GdkPixbuf.pixbuf;
      web_p : GdkPixbuf.pixbuf;
      nrock_p : GdkPixbuf.pixbuf;
      nweb_p : GdkPixbuf.pixbuf;
      ant_n_p : GdkPixbuf.pixbuf;
      ant_e_p : GdkPixbuf.pixbuf;
      ant_s_p : GdkPixbuf.pixbuf;
      ant_w_p : GdkPixbuf.pixbuf;
    }

type controls =
    {
      window: GWindow.window;
      button_prev: GButton.tool_button;
      button_next: GButton.tool_button;
      button_play: GButton.toggle_tool_button;
      button_backward: GButton.toggle_tool_button;
      button_forward: GButton.toggle_tool_button;
      button_refresh: GButton.tool_button;
      px: GMisc.image;
      interprets: GEdit.combo;
      levels: GEdit.combo;
      view_prog: GSourceView.source_view;
      view_mesg: GText.view;
      view_comment: GMisc.label;
    }

let gtk_init () =
  let _ = GtkMain.Main.init () in
  GtkSignal.user_handler := Pervasives.raise;
  (* work around messed up lablgtk *)
  Sys.catch_break false;
  Sys.set_signal Sys.sigpipe (Sys.Signal_default);
  Sys.set_signal Sys.sigterm (Sys.Signal_default);
  Sys.set_signal Sys.sigquit (Sys.Signal_default);
  let pix p =
    let file = Res.get ["tiles"; p ^ ".svg"] in
    GdkPixbuf.from_file_at_size file tile_size tile_size
  in
  {
    void_p = pix "void";
    exit_p = pix "exit";
    wall_p = pix "wall";
    rock_p = pix "rock";
    web_p = pix "web";
    nrock_p = pix "nrock";
    nweb_p = pix "nweb";
    ant_n_p = pix "ant-n";
    ant_e_p = pix "ant-e";
    ant_s_p = pix "ant-s";
    ant_w_p = pix "ant-w";
  }

let draw_state state ressources (pixmap : GDraw.pixmap) =
  let tile i j p =
    pixmap#put_pixbuf
      ~x:(tile_size/2+i*tile_size) ~y:(tile_size/2+j*tile_size) p
  in
  let i0, j0 = state.State.pos in
  let p i j t =
    begin match t with
    | `Void -> tile i j ressources.void_p
    | `Exit -> if i <> i0 || j <> j0 then tile i j ressources.exit_p
    | `Wall -> tile i j ressources.wall_p
    | `Rock -> tile i j ressources.rock_p
    | `Web -> tile i j ressources.web_p
    | `NRock -> tile i j ressources.nrock_p
    | `NWeb -> tile i j ressources.nweb_p
    end
  in
  Array.iteri (fun j a -> Array.iteri (fun i t -> p i j t) a) state.State.map;
  begin match state.State.dir with
  | `N -> tile i0 j0 ressources.ant_n_p
  | `E -> tile i0 j0 ressources.ant_e_p
  | `S -> tile i0 j0 ressources.ant_s_p
  | `W -> tile i0 j0 ressources.ant_w_p
  end;
  begin match state.State.carry with
  | `Rock -> tile i0 j0 ressources.rock_p
  | _ -> ()
  end

let labeled_combo text packing =
  let box = GPack.hbox ~packing () in
  let _ = GMisc.label ~text ~xpad:5 ~packing:box#pack () in
  GEdit.combo ~packing:box#add ()

let label_language = F.x "Language:" []
let label_level = F.x "Level:" []

let layout () =
  let monofont = Pango.Font.from_string "monospace" in
  let window = GWindow.window ~resizable:true () in
  let hpaned = GPack.paned `HORIZONTAL ~packing:window#add () in
  hpaned#set_position 650;
  let lvbox = GPack.vbox ~packing:hpaned#add1 () in
  let vpaned = GPack.paned `VERTICAL ~packing:hpaned#add () in
  vpaned#set_position 450;
  let scrolled ?(vpolicy=`ALWAYS) packing =
    GBin.scrolled_window ~packing ~hpolicy:`AUTOMATIC ~vpolicy ()
  in
  let sw_prog = scrolled vpaned#add1 in
  let view_prog =
    GSourceView.source_view ~show_line_numbers:true ~packing:sw_prog#add
      ()
  in
  view_prog#set_indent 1;
  view_prog#misc#modify_font monofont;
  let rvbox = GPack.vbox ~packing:vpaned#add2 () in
  let interprets = labeled_combo (Fd.render_raw label_language) rvbox#pack in
  let sw_mesg = scrolled rvbox#add in
  let view_mesg = GText.view ~editable:false ~packing:sw_mesg#add  () in
  view_mesg#misc#modify_font monofont;
  let levels = labeled_combo (Fd.render_raw label_level) lvbox#pack in
  let view_comment = GMisc.label ~line_wrap:true ~packing:lvbox#pack () in
  let sw_laby = scrolled ~vpolicy:`AUTOMATIC lvbox#add in
  let px = GMisc.image ~packing:sw_laby#add_with_viewport () in
  let toolbar = GButton.toolbar ~packing:lvbox#pack ~style:`BOTH () in
  let button stock = GButton.tool_button ~packing:toolbar#insert ~stock () in
  let tbutton stock =
    GButton.toggle_tool_button ~packing:toolbar#insert ~stock ()
  in
  let button_prev = button `GO_BACK in
  let button_next = button `GO_FORWARD in
  let _ =
    GButton.separator_tool_item
      ~expand:false ~draw:true ~packing:toolbar#insert ()
  in
  let button_backward = tbutton `MEDIA_REWIND in
  let button_play = tbutton `MEDIA_PLAY in
  let button_forward = tbutton `MEDIA_FORWARD in
  let _ =
    GButton.separator_tool_item
      ~expand:true ~draw:false ~packing:toolbar#insert ()
  in
  view_prog#misc#grab_focus ();
  let button_refresh = button `REFRESH in
  {
    window = window;
    button_prev = button_prev;
    button_next = button_next;
    button_play = button_play;
    button_backward = button_backward;
    button_forward = button_forward;
    button_refresh = button_refresh;
    px = px;
    interprets = interprets;
    levels = levels;
    view_prog = view_prog;
    view_mesg = view_mesg;
    view_comment = view_comment;
  }

let make_pixmap level =
  let sizex, sizey = Level.size level in
  let width, height = tile_size * (1 + sizex), tile_size * (1 + sizey) in
  GDraw.pixmap ~width ~height ()

let display_gtk ?language_list () =
  let language_list =
    begin match language_list with
    | None | Some [] -> List.sort (compare) (Res.get_list ["run"])
    | Some l -> l
    end
  in
  let levels_list =
    List.sort (compare) (Res.get_list ~ext:"laby" ["levels"])
  in
  let bot = Bot.make () in
  let level = ref (Level.load (Res.get ["levels"; List.hd levels_list])) in
  let load () = Level.generate !level in
  let b_states = ref [] in
  let c_state = ref (load ()) in
  let n_states = ref [] in
  let bg = ref `WHITE in
  begin try
    let ressources = gtk_init () in
    let c = layout () in
    c.interprets#set_popdown_strings language_list;
    c.levels#set_popdown_strings levels_list;
    let pixmap = ref (make_pixmap !level) in
    c.view_comment#set_text (Level.comment !level);
    let destroy () =
      bot#close;
      c.window#destroy ();
      GMain.Main.quit ()
    in
    bot#errto (fun s -> c.view_mesg#buffer#insert s);
    let newinterpret () =
      let name = c.interprets#entry#text in
      begin match List.mem name language_list with
      | true ->
	  bot#set_buf (c.view_prog#buffer#get_text ());
	  bot#set_name name;
	  c.view_prog#buffer#set_text bot#get_buf;
	  let langf = Res.get ["run"; name; "lang"] in
	  begin match GSourceView.source_language_from_file langf with
	  | None -> log#warning (F.x "cannot load language file" []);
	  | Some l ->
	      c.view_prog#source_buffer#set_language l;
	      c.view_prog#source_buffer#set_highlight true;
	  end
      | false -> ()
      end
    in
    let step state =
      begin match bot#probe with
      | None -> None
      | Some (action, reply) ->
	  let answer, newstate = State.run action state in
	  reply answer;
	  Some newstate
      end
    in
    let bot_stop () =
      bot#close;
      c.view_mesg#buffer#set_text "";
      b_states := []; c_state := load (); n_states := [];
    in
    let bot_start () =
      bot#set_name (c.interprets#entry#text);
      bot#set_buf (c.view_prog#buffer#get_text ());
      if bot#start
      then c_state := { !c_state with State.action = `Start }
    in
    let update ?(first=false) () =
      !pixmap#set_foreground !bg;
      let width, height = !pixmap#size in
      !pixmap#rectangle ~x:0 ~y:0 ~width ~height ~filled:true ();
      draw_state !c_state ressources !pixmap;
      c.px#set_pixmap !pixmap;
      let say msg = c.view_mesg#buffer#insert (Fd.render_raw msg ^ "\n") in
      let repport () =
	begin match !c_state.State.action with
	| `Start -> say Say.start
	| `Wall_In -> say Say.wall_in
	| `Rock_In -> say Say.rock_in
	| `Exit_In -> say Say.exit_in
	| `Web_In -> say Say.web_in
	| `Web_Out -> say Say.web_out
	| `Exit -> say Say.exit
	| `No_Exit -> say Say.no_exit
	| `Carry_Exit -> say Say.carry_exit
	| `Rock_No_Take -> say Say.rock_no_take
	| `Rock_No_Drop -> say Say.rock_no_drop
	| _ -> ()
	end
      in
      if first then (repport (); Sound.action !c_state.State.action)
    in
    let inactive () =
      c.button_forward#set_active false;
      c.button_backward#set_active false;
      c.button_play#set_active false
    in
    let refresh () =
      inactive ();
      bot_stop ();
      bot_start ();
      update ~first:true ();
    in
    let newlevel () =
      let name = c.levels#entry#text in
      begin match List.mem name levels_list with
      | true ->
	  level := Level.load (Res.get ["levels"; name]);
	  pixmap := make_pixmap !level;
	  c.view_comment#set_text (Level.comment !level);
	  inactive ();
	  bot_stop ();
	  update ();
      | false -> ()
      end
    in
    if List.mem "ocaml" language_list
    then c.interprets#entry#set_text "ocaml";
    newinterpret ();
    let prev () =
      begin match !b_states with
      | [] -> inactive ()
      | x :: q ->
	  b_states := q; n_states := !c_state :: !n_states; c_state := x;
	  update ()
      end
    in
    let next () =
      begin match !n_states with
      | [] ->
	  begin match step !c_state with
	  | Some x ->
	      b_states := !c_state :: !b_states; c_state := x;
	      update ~first:true ()
	  | None -> inactive ()
	  end
      | x :: q ->
	  b_states := !c_state :: !b_states; c_state := x; n_states := q;
	  update ()
      end
    in
    let play =
      let rid = ref None in
      begin fun direction speed () ->
	begin match !rid with
	| None ->
	    let callback () =
	      begin match direction with
	      |	`Forward -> next (); true
	      | `Backward -> prev (); true
	      end
	    in
	    rid := Some (GMain.Timeout.add ~ms:speed ~callback);
	| Some id ->
	    inactive ();
	    GMain.Timeout.remove id; rid := None
	end
      end
    in
    ignore (c.window#event#connect#delete ~callback:(fun _ -> destroy(); true));
    ignore (c.window#connect#destroy ~callback:destroy);
    ignore (c.button_prev#connect#clicked ~callback:prev);
    ignore (c.button_next#connect#clicked ~callback:next);
    ignore (c.button_play#connect#toggled ~callback:(play `Forward 500));
    ignore (c.button_backward#connect#toggled ~callback:(play `Backward 100));
    ignore (c.button_forward#connect#toggled ~callback:(play `Forward 100));
    ignore (c.button_refresh#connect#clicked ~callback:refresh);
    ignore (c.interprets#entry#connect#changed ~callback:newinterpret);
    ignore (c.levels#entry#connect#changed ~callback:newlevel);
    c.window#set_default_size 1000 725;
    c.window#show ();
    (* bg color has to be retrieved after c.window#show *)
    bg := `COLOR (c.px#misc#style#light `NORMAL);
    update ();
    ignore (GMain.Main.main ())
  with
  | Gtk.Error m ->
      raise (
	Error (
	  F.x "gtk error: <error>" ["error", F.q (F.string m)]
	)
      )
  end