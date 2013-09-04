import core.sync.mutex : Mutex;
import goroutine : sleep;
import std.datetime : dur;
import std.traits : isInstanceOf;
//void select(T)(T...) if (isMadeOf(chan)) { go through each arg and first !arg.empty is winner }



/**
 * chan allows messaging between threads without having to deal with locks, similar to how chan works in golang
 */
shared
class chan(T) {
	Mutex lock;
	private bool closed_; bool closed() {synchronized (lock) {return closed_;}} void close() { synchronized(lock) { closed_ = true; } }

	struct Container(T) {
		T value;
		Container!T* next;
	}
	Container!T* current;
	Container!T* last;
	size_t length;
	void insert(T v) {
		Container!T* newItem = new Container!T();
		newItem.value = v;
		synchronized (lock) {
			if (current is null) {
				current = cast(shared)newItem;
				last = cast(shared)newItem;
			} else {
				last.next = cast(shared)newItem;
				last = cast(shared)newItem;
			}
			length++;
		}
	}
	T getone() {
		T ret;
		synchronized (lock) {
			ret = cast(T)current.value;
			current = current.next;
			length--;
		}
		return ret;
	}
	size_t maxItems;
	bool blockOnFull = false;
	this(int maxItems = 1024, bool blockOnFull = true) {
		lock = cast(shared)new Mutex;
		length = 0;

		this.maxItems = maxItems;
		this.blockOnFull = blockOnFull;
	}

	@property
	void _(T value) {
		bool done;
		while(true) {
			synchronized(lock) {
				if (closed) {
					throw new ChannelClosedException();
				}
				if (!done && length < maxItems) {
					insert(value);
					done = true;
				} else if (!blockOnFull) {
					throw new ChannelFullException("Channel Full");
				}
				if (length <= maxItems-1) {
					break;
				}
			}
			sleep(dur!"msecs"(1));
		}
	}
	@property
	T _() {
		_startagain:
		while(true) {
			size_t len;
			synchronized(lock) {
				len = length;
				if (len <= 0 && closed) {
					throw new ChannelClosedException("on read");
				}
			}
			if (len > 0) {
				break;
			}
			sleep(dur!"msecs"(1));
		};
		T r;
		synchronized(lock) {
			auto len = length;
			if (len <= 0) {
				goto _startagain;
			}
			r = getone();
		}
		return r;
	}
	T popFront() {
		return _();
	}
	T front() {
		synchronized (lock) {
			return cast(T)current.value;
		}
	}
	void put(T v) {
		_(v);
	}

	// check if there is something to read, chan will block if this returns false and you call _().
	// NOTE: if another thread empties the chan between a call to this function and a call to _() the
	// calling fiber/Thread will block
	@property
	bool empty() {
		bool ret;
		synchronized (lock) {
			ret = length <= 0;
		}
		return ret;
	}

	// check if there is space in the chan to write to, chan will block if this returns false and you call _(T).
	// NOTE: if another thread fills the chan between a call to this function and a call to _(T) the
	// calling fiber/Thread will block
	@property
	bool writable() {
		bool ret;
		synchronized (lock) {
			ret = length < maxItems;
		}
		return ret;
	}
/+
	void opAssign(T v) {
		_(v);
	}
	@property
	T get() {
		return _();
	}
	alias get this;+/
}
shared(chan!T) makeChan(T)(int n, bool blockOnFull = true) {
	return cast(shared)(new chan!T(n, blockOnFull));
}




int select(Args...)(Args args) if (allischan!Args()) {
	import std.random : uniform;

	while (true) {
		int[] ready;
		int closed;
		ready.reserve(args.length);
		foreach (i, arg; args) {
			if (arg.closed)
				closed++;
			if (!arg.empty)
				ready ~= i;
		}
		if (closed >= args.length) {
			return -1;
		}
		if (ready.length > 0) {
			auto idx = uniform(0,ready.length);
			return ready[idx];
		}
		sleep();
	}
}
int select(Args...)(Args args) if (!allischan!Args()) {
	import std.conv;
	foreach (i, arg; Args) {
		static if (!isInstanceOf!(chan, arg)) {
			static assert(0, "select(Args args) only accepts parameters of type: shared(chan) not argument "~ to!string(i+1) ~" of type: "~ arg.stringof);
		}
	}
	assert(0, "should never reach here");
}


bool allischan(Args...)() {
	foreach (arg; Args) {
		static if (!isInstanceOf!(chan, arg)) {
			return false;
		}
	}
	return true;
}

class ChannelException : Exception {
	this(string msg) {
		super(msg,file,line,next);
	}
}
class ChannelFullException : Exception {
	this(string msg = "Channel Full") {
		super(msg,file,line,next);
	}
}
class ChannelClosedException : Exception {
	this(string msg = "Channel Closed") {
		super(msg,file,line,next);
	}
}