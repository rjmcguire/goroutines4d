import std.datetime;

import channel;
import goroutine;

auto After(Duration d) {
	auto ch = makeChan!bool(1); // make it 1 so it blocks

	go!({
		sleep(d);
		ch._ = true;
		ch.close();
		});

	return ch;
}


auto Ticker(Duration d) {
	auto ch = makeChan!bool(1); // make it 1 so it blocks

	go!({
		while (!ch.closed) {
			sleep(d);
			ch._ = true;
		}
		ch.close();
		});

	return ch;
}