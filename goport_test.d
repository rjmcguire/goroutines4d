import std.stdio;
import std.datetime;

import channel;
import goroutine;
import time;
import sync;

void main() {
	auto ticker = Ticker(dur!"msecs"(10));
	go!({for (int i=0; i<10; i++) {
		writeln("tick ", ticker._);
	}});

	writeln("=-=========-=");
	auto ch = makeChan!int(1);
	go!({
			foreach (i; 22..444) {
				ch._ = i;
			}
			ch.close();
			writeln("done");
		});

	foreach (i; 0..400) {
		writeln("pop: ", ch._);
	}


	writeln("=-=========-=");
	writeln(Clock.currTime);
	After(dur!"msecs"(1000));
	writeln(Clock.currTime);
	writeln("done 1 secs");

	while (!ch.empty) {
		writeln(ch._);
	}

	auto timeoutch = After(dur!"msecs"(100));
	while (true) {
		switch (select(ch, timeoutch)) {
			case 0:
				writeln("zero", ch._);
				break;
			case 1:
				writeln("time is up", timeoutch._);
				break;
			case -1: // all closed
				goto outahere;
			default:
				sleep();
		}
	}
	outahere:
	return;
}