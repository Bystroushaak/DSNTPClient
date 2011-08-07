/**
 * DigitalMars D SNTP client.
 * 
 * This module allows get time from ntpserver with very low precision (1s).
 * 
 * See wikipedia for details: http://en.wikipedia.org/wiki/Network_Time_Protocol 
 * 
 * Author:
 * 	Bystroushaak (bystrousak@kitakitsune.org)
 * Version:
 * 	1.0.0
 * Date:
 * 	07.08.2011
 * Copyright:
 * 	This work is licensed under a Creative Commons Attribution 3.0 Unported License
 * 	(http://creativecommons.org/licenses/by/3.0/).
*/ 

module sntpclient;


import std.bitmanip;
import std.stdint;

import std.socket;
import std.socketstream;

import std.system;


/***/
public enum LeapIndicator {NoWarning = 0, SixtyOneSec, FiftyOneSec, AlarmCondition};
/***/
public enum Mode {Reserved = 0, SymetricActive, SymetricPasive, Client, Server, Broadcast, ReservedNTP, ReservedPrivate};


/**
 * SNTP packet.
 * 
 * For details, see RFC 1361 (http://www.faqs.org/rfcs/rfc1361.html)
*/
public struct SNTPmsg{
	mixin(bitfields!(
		uint, "LI", 2,  // leap indicator
		uint, "VN", 3,  // version number
		uint, "Mode", 3
	));
	uint8_t  Stratum;
	int8_t   Poll;
	int8_t   Precision;
	int32_t  RootDelay;
	uint32_t RootDispersion;
	uint32_t RCI;
	uint64_t ReferenceTimestamp;
	uint64_t OriginateTimestamp;
	uint64_t ReceiveTimestamp;
	uint64_t TransmitTimestamp;
}


// Initialize SNTP packet
private void initSNTPmsg(ref SNTPmsg m){
	m.LI   = LeapIndicator.AlarmCondition;
	m.VN   = 2;
	m.Mode = Mode.Client;
	m.Stratum = 0;
	m.Poll    = 4;
	m.Precision = 0;
	m.RootDelay = 0;
	m.RootDispersion = 0;
	m.RCI = 0;
	m.ReferenceTimestamp = 0;
	m.OriginateTimestamp = 0;
	m.ReceiveTimestamp   = 0;
	m.TransmitTimestamp  = 0;
}


/**
 * Get SNTP packet from server.
*/
public SNTPmsg getSNTPmsg(string server, ushort port = 123){
	SNTPmsg m;
	initSNTPmsg(m);
	
	Socket s = new UdpSocket(AddressFamily.INET);
	s.connect(new InternetAddress(server, port));
	
	SocketStream ss = new SocketStream(s);
	ss.writeBlock(&m, m.sizeof);			// send blank message
	ss.readBlock(&m, m.sizeof);				// get ntp timestamps
	ss.close();
	
	return m;
}

// Convert endianity
private uint16_t swap16(uint16_t i) {
    ubyte *c = cast(ubyte *) &i;
    ubyte o[2] = [c[1], c[0]];
    return * cast(uint16_t *) o;
}


/**
 * Convert time from NTP timestamp to Unix timestamp.
 * 
 * Function is checking endianity, so it should works on every platform.
 * 
 * Thx to http://arduino.cc/forum/index.php/topic,51802.msg369313.html#msg369313
*/ 
public uint32_t toUnixTimestamp(uint64_t t){	
	struct hilow{
		uint16_t hiWord;
		uint16_t loWord;
		uint32_t crap; 
	}
	
	// read data into structure (simplify parsing)
	hilow *hl = cast(hilow*) &t;
	
	// endianity - forever pain in the ass
	uint32_t ss1900;
	if (endian == Endian.LittleEndian)
		ss1900 = swap16(hl.hiWord) << 16 | swap16(hl.loWord);
	else
		ss1900 = hl.hiWord << 16 | hl.loWord;
	
	return ss1900 - 2208988800u; // 2208988800 = 70 years (unix timestamp starts 1970, ntp 1900)
}


/**
 * Get time from ntpserver and return it converted into 32b unix timestamp.
*/ 
public uint32_t getUnixTimestamp(string server, ushort port = 123){
	return toUnixTimestamp(getSNTPmsg(server, port).TransmitTimestamp);
}