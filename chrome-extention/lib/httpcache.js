window.Cache = (function(){
var $K = function(i){
  return function(){ return i };
};

function http (opts) {
	var d = Deferred();
	var req = new XMLHttpRequest();
	req.open(opts.method, opts.url, true);
	if (opts.headers) {
		for (var k in opts.headers) if (opts.headers.hasOwnProperty(k)) {
			req.setRequestHeader(k, opts.headers[k]);
		}
	}
	req.onreadystatechange = function () {
		if (req.readyState == 4) d.call(req);
	};
	req.send(opts.data || null);
	d.xhr = req;
	return d;
}
http.get   = function (url)       { return http({method:"get",  url:url}) };
http.post  = function (url, data) { return http({method:"post", url:url, data:data, headers:{"Content-Type":"application/x-www-form-urlencoded"}}) };

function Cache () {};
Cache.ts = function () {
  return (new Date()) - 0;
};
Cache.defaultExpire = 60 * 15;
Cache.prototype = {
  data: {},
  get: function (key) {
    var self = this;
    var cache = this.data[key];
    if (cache && cache.expire && Cache.ts() <= cache.expire) {
      return Deferred.next($K(cache.value));
    } else {
      return http.get(key).next(function(res){
        self.set(key, res);
        return res;
      }).error(function(){
        self.set(key, null);
        return null;
      });
    }
  },
  set: function (key, value, second) {
    if (!second) second = Cache.defaultExpire;
    var cache_time = +(new Date()) + second * 1000;
    this.data[key] = {
      value: value,
      expire: cache_time
    };
  },
  delete: function (key) {
    delete this.data[key];
  }
};
Cache.counter = new Cache();

return Cache;
})();