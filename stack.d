shared struct SharedStack(T) {
	private shared struct Node {
		T _value;
		Node* _next;
		this(T value){ _value = cast(shared)value;};
	}
	private Node* _root;

	void put(T value){
		auto n = new shared Node(value);
		shared(Node)* oldRoot;
		do {
			oldRoot = _root;
			n._next = oldRoot;
		} while(!cas(&_root,oldRoot,n));
	}

	T* popFront() {
		typeof(return) ret;
		shared(Node)* oldRoot;
		do {
			oldRoot = _root;
			if (_root is null) return null;
			ret = cast(T*)&oldRoot._value;
		} while (!cas(&_root, oldRoot, oldRoot._next));

		return ret;
	}
	T* front() {
		if (_root is null)
			return null;
		return cast(T*)_root._value;
	}
}


/*
Still need to learn from http://www.drdobbs.com/parallel/writing-a-generalized-concurrent-queue/211601363?pgno=2

shared struct SharedFifo(T) {
	private shared struct Node {
		T _value;
		Node* _next;
		this(T value){ _value = cast(shared)value;};
	}
	private Node* _root;
	private Node* _divider;
	private Node* _last;
	this(int i) {
		_root = _divider = _last = new shared Node(T.init);
		_last._next = new shared Node(T.init);
	}

	~this() {
		while (_root !is null) {
			auto tmp = _root;
			_root = _root._next;
			tmp._next = null;
		}
	}

	void put(T value){
		// this is safe in a single producer environment because the consumer never reads the last item in the queue, see front and or popFront
		_last._next = new shared Node(value);
		_last = _last._next;
		//writeln("put %s %s %s", _last, cast(T)_last._value);

		while (_root != _divider) {
			auto tmp = _root;
			_root = _root._next;

			tmp._next = null; // the closest to delete I've got
			delete tmp;
		}
	}

	T* popFront() {
		if (_divider == _last) return null;

		auto ret = &_divider._next._value;
		_divider = _divider._next;
		//writeln("pop: %s %s %s", _divider, _divider._next, cast(T)_divider._next._value);
		return cast(T*)ret;
	}
	T* front() {
		if (_divider == _last) return null;

		auto ret = _divider._next._value;
		return cast(T*)ret;
	}

	void opAssign(shared SharedFifo!T rhs) {
		this._root = rhs._root;
		this._divider = rhs._divider;
		this._last = rhs._last;
	}
}
*/