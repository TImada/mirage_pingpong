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

type stats = {
   mutable bytes: int64;
   mutable start_time: int64;
   mutable last_time: int64;
}

module Main (S: Tcpip.Stack.V4) (Time : Mirage_time.S) (Mclock : Mirage_clock.MCLOCK) = struct

  let server_ip = Ipaddr.V4.of_string_exn "192.168.122.100"
  let port = 7001

  let msg = "0"

  let mlen = String.length msg

  let print_data st =
    let duration = Int64.sub st.last_time st.start_time in
    Logs.info (fun f -> f  "Latency = %.0Lu [ns]" duration);
    Lwt.return_unit

  let err_connect ip port () =
    let ip  = Ipaddr.V4.to_string ip in
    Logs.info (fun f -> f "Unable to connect to %s:%d" ip port);
    Lwt.return_unit

  let write_and_check flow buf =
    S.TCPV4.write flow buf >|= Rresult.R.get_ok

  let tcp_connect t (ip, port) =
    S.TCPV4.create_connection t (ip, port) >|= Rresult.R.get_ok

  let read_response flow clock st =
    let read_h flow clock st =
      S.TCPV4.read flow >|= Rresult.R.get_ok >>= function
      | `Eof ->
        Logs.info (fun f -> f  "pingpong client: unexpectedly closed connection.");
        Lwt.return_unit
      | `Data data ->
        let ts_now = Mclock.elapsed_ns clock in
        let l = Cstruct.length data in
        st.last_time <- ts_now;
        st.bytes <- (Int64.add st.bytes (Int64.of_int l));
        print_data st
    in
    read_h flow clock st

  let pingpongclient s dest_ip dport clock =
    (* Setting up a buffer and a timer *)
    let a = Cstruct.sub (Io_page.(to_cstruct (get 1))) 0 mlen in
    Cstruct.blit_from_string msg 0 a 0 mlen;
    Logs.info (fun f -> f  "Trying to connect to a server at %s:%d, buffer size = %d" (Ipaddr.V4.to_string server_ip) port mlen);

    let rec loop n flow clock buf =
      match n with
      | 0 -> Lwt.return_unit
      | n -> 
        let t0 = Mclock.elapsed_ns clock in
        let st = {
          bytes=0L; start_time = t0; last_time = t0
        } in
        (* Data sending *)
        write_and_check flow buf >>= fun () ->
        (* Receiving reqsponse *)
        read_response flow clock st >>= fun () ->
        loop (n-1) flow clock buf
    in

    (* Having a connection *)
    Logs.info (fun f -> f  "pingpong client: Connecting.");
    tcp_connect (S.tcpv4 s) (dest_ip, dport) >>= fun flow ->

    (* Latency testing *)
    loop 1000 flow clock a >>= fun () ->

    (* Connection closing *)
    Logs.info (fun f -> f  "pingpong client: Closing.");
    S.TCPV4.close flow >>= fun () ->
    Lwt.return_unit

  let start s _time _clock =
    Time.sleep_ns (Duration.of_sec 1) >>= fun () -> (* Give server 1.0 s to call listen *)
    Lwt.async (fun () -> S.listen s);
    pingpongclient s server_ip port _clock

end

