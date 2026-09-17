module("luci.controller.xlnetacc", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/xlnetacc") then
		return
	end

	entry({"admin", "services", "xlnetacc"},
		firstchild(), _("XLNetAcc")).dependent = false

	entry({"admin", "services", "xlnetacc", "general"},
		cbi("xlnetacc"), _("Settings"), 1)

	entry({"admin", "services", "xlnetacc", "log"},
		template("xlnetacc/logview"), _("Log"), 2)

	entry({"admin", "services", "xlnetacc", "status"}, call("action_status"))
	entry({"admin", "services", "xlnetacc", "logdata"}, call("action_log"))
	entry({"admin", "services", "xlnetacc", "captcha"}, call("action_captcha"))
	entry({"admin", "services", "xlnetacc", "captcha_submit"}, post("action_captcha_submit"))
end

local function is_running(name)
	return luci.sys.call("pidof %s >/dev/null" %{name}) == 0
end

function action_status()
	local captcha_path = "/tmp/xlnetacc_verify.jpg"
	local captcha_key_path = "/tmp/xlnetacc_verify_key"
	local captcha_stat = nixio.fs.stat(captcha_path)
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		run_state = is_running("xlnetacc.sh"),
		down_state = nixio.fs.readfile("/var/state/xlnetacc_down_state") or "",
		up_state = nixio.fs.readfile("/var/state/xlnetacc_up_state") or "",
		captcha_pending = captcha_stat ~= nil and nixio.fs.access(captcha_key_path),
		captcha_id = captcha_stat and
			(tostring(captcha_stat.mtime or 0) .. "-" .. tostring(captcha_stat.size or 0)) or "0"
	})
end

function action_captcha()
	local image = nixio.fs.readfile("/tmp/xlnetacc_verify.jpg")
	if not image or not nixio.fs.access("/tmp/xlnetacc_verify_key") then
		luci.http.status(404, "Captcha not available")
		return
	end

	luci.http.header("Cache-Control", "no-store, no-cache, must-revalidate")
	luci.http.header("Pragma", "no-cache")
	luci.http.prepare_content("image/jpeg")
	luci.http.write(image)
end

function action_captcha_submit()
	local http = require "luci.http"
	local i18n = require "luci.i18n"
	local util = require "luci.util"
	local code = util.trim(http.formvalue("code") or "")

	http.prepare_content("application/json")
	if http.getenv("REQUEST_METHOD") ~= "POST" then
		http.status(405, "Method Not Allowed")
		http.write_json({ ok = false, message = i18n.translate("Please submit the captcha from the page.") })
		return
	end

	if not nixio.fs.access("/tmp/xlnetacc_verify.jpg") or
	   not nixio.fs.access("/tmp/xlnetacc_verify_key") then
		http.status(409, "Captcha not available")
		http.write_json({ ok = false, message = i18n.translate("The captcha has expired. Please wait for a new one.") })
		return
	end

	if #code < 4 or #code > 8 or not code:match("^[A-Za-z0-9]+$") then
		http.status(400, "Invalid captcha")
		http.write_json({ ok = false, message = i18n.translate("Enter 4 to 8 letters or numbers.") })
		return
	end

	local tmp_path = "/tmp/xlnetacc_verify_code.new"
	if not nixio.fs.writefile(tmp_path, code) or not os.rename(tmp_path, "/tmp/xlnetacc_verify_code") then
		http.status(500, "Unable to save captcha")
		http.write_json({ ok = false, message = i18n.translate("Unable to submit the captcha.") })
		return
	end
	nixio.fs.chmod("/tmp/xlnetacc_verify_code", "0600")
	http.write_json({ ok = true, message = i18n.translate("Captcha submitted. Logging in...") })
end

function action_log()
	local uci = require "luci.model.uci".cursor()
	local util = require "luci.util"
	local log_data = { }

	log_data.syslog = util.trim(util.exec("logread | grep xlnetacc"))
	if uci:get("xlnetacc", "general", "logging") ~= "0" then
		log_data.client = nixio.fs.readfile("/var/log/xlnetacc.log") or ""
	end
	uci:unload("xlnetacc")

	luci.http.prepare_content("application/json")
	luci.http.write_json(log_data)
end
