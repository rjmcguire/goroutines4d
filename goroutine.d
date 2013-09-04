import core.thread : Thread, Fiber, thread_isMainThread, getpid;
import std.conv;
import std.process : environment;
import std.datetime;
import std.stdio : stderr;

import core.sys.posix.signal : kill, SIGABRT;

import channel;

void go(alias F)() {
	scheduler._ = new Fiber(F);
}
/// sleep for d duration, uses Fiber.yield if running in a Fiber.
void sleep(Duration d = dur!"usecs"(1)) {
	if (Fiber.getThis() is null) {
		Thread.sleep(d);
	} else {
		auto begin = Clock.currTime();
		for (;;Fiber.yield()) {
			auto now = Clock.currTime();
			if (now - begin > d) {
				break;
			}
		}
	}
}

// TODO: Scheduler should take sleep time into account.


shared chan!Fiber scheduler; // channel contains Fibers waiting for their time slice
shared static this () {
	scheduler = makeChan!Fiber(100);

	// create the workers
	auto goprocs = environment.get("GOPROCS");
	int num_threads = 1;
	if (goprocs != null) {
		num_threads = to!int(goprocs);
	}
	foreach (i; 0..num_threads) {
		// create threads that process the live fibers
		auto t = new Thread(() {
				for (;;) {
					Fiber fiber;
					try {
						fiber = scheduler._;
					} catch (ChannelClosedException cce) {
						break;
					}

					// don't catch any exceptions from the user code
					try {
						fiber.call();
					} catch (Exception e) {
						// we catch Error here because I hate it when runtime exceptions are swallowed with no evident of happening
						// e.g. An assert(false) in a fiber would be hidden unless we caught this Error, 
						stderr.writeln(e);
					} catch (Error e) {
						// we catch Error here because I hate it when runtime exceptions are swallowed with no evident of happening
						// e.g. An assert(false) in a fiber would be hidden unless we caught this Error, 
						stderr.writeln(e);
						kill(getpid(), SIGABRT);
					}

					if (fiber.state != Fiber.State.TERM) {
						try {
							scheduler._ (fiber);
						} catch (ChannelClosedException cce) {
							break;
						}
					}
					//Thread.sleep(dur!"usecs"(1));
				}
			});
		t.start();
	}
}
static ~this() {
	if (thread_isMainThread()) {
		scheduler.close();
	}
}
