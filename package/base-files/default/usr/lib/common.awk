function portstr(type, str) {
	if (str ~ /^[0-9]+-[0-9]+$/) {
		gsub(/-/, ":", str)
		if (type == "src") return " --sport " str
		else return " --dport " str
	} else {
		if (insmod_mport != 1) {
			print "insmod ipt_multiport >&- 2>&-"
			insmod_mport = 1
		}
		if (type == "src") return " -m multiport --sports " str
		else return " -m multiport --dports " str
	}
}

function str2ipt(str) {
	str2data(str)
	_cmd = ""
	if (_l["src"] != "") _cmd = _cmd " -s " _l["src"]
	if (_l["dest"] != "") _cmd = _cmd " -d " _l["dest"]
	if (_l["proto"] != "") {
		_cmd = _cmd " -p " _l["proto"]
	}
	# scripts need to check for proto="" and emit two rules in that case
	if ((_l["proto"] == "") || (_l["proto"] == "tcp") || (_l["proto"] == "udp")) {
		if (_l["sport"] != "") _cmd = _cmd portstr("src", _l["sport"])
		if (_l["dport"] != "") _cmd = _cmd portstr("dest", _l["dport"])
	}
	if (_l["layer7"] != "") {
		if (insmod_l7 != 1) {
			print "insmod ipt_layer7 >&- 2>&-"
			insmod_l7 = 1
		}
		_cmd = _cmd " -m layer7 --l7proto " _l["layer7"]
	}
	return _cmd
}

function str2data(str) {
	delete _l
	_n = split(str, _o, "[\t ]")
	for (_i = 1; _i <= _n; _i++) {
		_n2 = split(_o[_i], _c, "=")
		if (_n2 == 2) _l[_c[1]] = _c[2]
	}
}
