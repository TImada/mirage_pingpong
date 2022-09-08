(*
 * Copyright (c) 2011 Richard Mortier <mort@cantab.net>
 * Copyright (c) 2012 Balraj Singh <balraj.singh@cl.cam.ac.uk>
 * Copyright (c) 2015 Magnus Skjegstad <magnus@skjegstad.com>
 * Copyright (c) 2017 Takayuki Imada <takayuki.imada@gmail.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Lwt.Infix

module Main (S: Tcpip.Stack.V4V6) = struct

   let return_ip = Ipaddr.of_string_exn "192.168.122.101"
   let port = 7001

   let msg = "0"
   let mlen = String.length msg
   let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen

   let err_connect ip port () =
     let ip  = Ipaddr.to_string ip in
     Logs.info (fun f -> f "Unable to connect to %s:%d" ip port);
     Lwt.return_unit

   let err_write () =
     Logs.info (fun f -> f "Error while writing to TCP flow.");
     Lwt.return_unit

   let write_and_check flow buf =
     (*Logs.info (fun f -> f "Writing.");*)
     S.TCP.write flow buf >|= Rresult.R.get_ok

   let receiver flow =
     let rec pingpong_h flow =
       S.TCP.read flow >|= Rresult.R.get_ok >>= function
       | `Eof ->
         Logs.info (fun f -> f  "pingpong server: connection closed.");
         Lwt.return_unit
       | `Data _ ->
         begin
           (*Logs.info (fun f -> f  "pingpong server: connected.");*)
           write_and_check flow a >>= fun () ->
           (*Logs.info (fun f -> f  "pingpong server: Done - responded.");*)
           pingpong_h flow
         end
     in
     pingpong_h flow

  let start s =
    let ips = List.map Ipaddr.to_string (S.IP.get_ip (S.ip s)) in
    Logs.info (fun f -> f "pingpong server process started:");
    Logs.info (fun f -> f "IP address: %s" (String.concat "," ips));
    Logs.info (fun f -> f "Port number: %d" port);

    S.TCP.listen (S.tcp s) ~port:port (fun flow ->
      receiver flow
    );
    S.listen s

end

