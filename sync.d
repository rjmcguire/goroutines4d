import core.atomic : cas;
	import std.stdio;

class Bool {
	bool v;
	this(bool v) { this.v = v;}
}
shared True = true;
const shared False = false;

struct Once(alias F) {
	shared bool done;
	void Do() {
		if (cas(&done, False, True)) {
			F();
		}

	}
}











unittest {
	import channel;
	import goroutine;
	import std.stdio;

	auto onceBody = () {
		writeln("Only once");
	};
	auto once = Once!onceBody();

	auto done = makeChan!(bool)(1);
	for (auto i = 0; i < 10; i++) {
		go!({
			once.Do();
			done._ = true;
		});
	}
	for (auto i = 0; i < 10; i++) {
		done._;
	}
}