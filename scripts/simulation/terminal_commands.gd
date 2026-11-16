class_name TerminalCommands
extends RefCounted
## The complete list of things the simulated terminal can do. Anything not in
## TABLE does nothing. Handlers are chosen by `match` on the command key in
## TerminalParser, never looked up from player text.

const BANNER: String = "SIMULATED ENVIRONMENT - NO HOST COMMANDS"

## key -> {summary, usage, example, positional_min, positional_max, options}
const TABLE: Dictionary = {
	"help": {
		"summary": "List the commands, or explain one.",
		"usage": "help [command]",
		"example": "help logs search",
		"positional_min": 0, "positional_max": 2, "options": [],
	},
	"clear": {
		"summary": "Clear the screen.",
		"usage": "clear",
		"example": "clear",
		"positional_min": 0, "positional_max": 0, "options": [],
	},
	"history": {
		"summary": "Show the commands you have run.",
		"usage": "history",
		"example": "history",
		"positional_min": 0, "positional_max": 0, "options": [],
	},
	"assets list": {
		"summary": "List the computers, systems and services in this scenario.",
		"usage": "assets list",
		"example": "assets list",
		"positional_min": 0, "positional_max": 0, "options": [],
	},
	"hosts show": {
		"summary": "Show one workstation and the recent events on it.",
		"usage": "hosts show <host>",
		"example": "hosts show HOST-014",
		"positional_min": 1, "positional_max": 1, "options": [],
	},
	"logs search": {
		"summary": "Search the log events with simple filters.",
		"usage": "logs search [source=auth|mfa|app|helpdesk] [user=NAME] [result=success|failure|requested|reported] [ip=LABEL] [device=NAME] [contains=TEXT] [after=HH:MM] [before=HH:MM] [limit=1-50]",
		"example": "logs search source=auth user=j.smith after=09:00",
		"positional_min": 0, "positional_max": 0,
		"options": ["source", "user", "result", "ip", "device", "contains", "after", "before", "limit"],
	},
	"evidence add": {
		"summary": "Collect a log event as evidence.",
		"usage": "evidence add <event> [CASE-001] [note=\"text\"]",
		"example": "evidence add EVT-004 CASE-001",
		"positional_min": 1, "positional_max": 2, "options": ["note"], "mutates": true,
	},
	"evidence list": {
		"summary": "List the evidence you have collected.",
		"usage": "evidence list",
		"example": "evidence list",
		"positional_min": 0, "positional_max": 0, "options": [],
	},
	"evidence remove": {
		"summary": "Remove a piece of evidence that no case entry cites.",
		"usage": "evidence remove <evidence-id>",
		"example": "evidence remove ev_001",
		"positional_min": 1, "positional_max": 1, "options": [], "mutates": true,
	},
	"case note": {
		"summary": "Record a fact, hypothesis or unknown in the case. Facts must cite evidence.",
		"usage": "case note CASE-001 \"text\" [kind=fact|hypothesis|unknown] [evidence=ev_001,ev_002]",
		"example": "case note CASE-001 \"Repeated failures then unusual success\"",
		"positional_min": 2, "positional_max": 2, "options": ["kind", "evidence"], "mutates": true,
	},
	"case severity": {
		"summary": "Set how serious you judge the case to be.",
		"usage": "case severity <low|medium|high|critical>",
		"example": "case severity high",
		"positional_min": 1, "positional_max": 1, "options": [], "mutates": true,
	},
	"case scope": {
		"summary": "List the assets you believe are affected.",
		"usage": "case scope <asset>[,<asset>...]",
		"example": "case scope host_014,member_portal",
		"positional_min": 1, "positional_max": 1, "options": [], "mutates": true,
	},
	"case show": {
		"summary": "Show the case: severity, scope and every entry.",
		"usage": "case show",
		"example": "case show",
		"positional_min": 0, "positional_max": 0, "options": [],
	},
	"timeline build": {
		"summary": "Show your evidence as a timeline.",
		"usage": "timeline build [CASE-001]",
		"example": "timeline build",
		"positional_min": 0, "positional_max": 1, "options": [],
	},
}

## Names of real-computer commands people reach for. They are refused with an
## explanation, never run, never looked at again.
const HOST_COMMANDS: Array[String] = [
	"dir", "ls", "cat", "type", "more", "less", "head", "tail", "rm", "del", "erase", "rd", "rmdir", "mkdir", "md",
	"cd", "chdir", "pwd", "cp", "copy", "xcopy", "mv", "move", "ren", "touch", "chmod", "chown", "ln", "find",
	"grep", "findstr", "awk", "sed", "sort", "whoami", "hostname", "uname", "id", "env", "set", "export", "echo",
	"curl", "wget", "ping", "tracert", "traceroute", "nslookup", "dig", "nmap", "ssh", "scp", "sftp", "telnet",
	"ftp", "nc", "ncat", "netcat", "netstat", "ifconfig", "ipconfig", "route", "arp", "powershell", "pwsh", "cmd",
	"bash", "sh", "zsh", "fish", "python", "python3", "py", "node", "perl", "ruby", "php", "java", "sudo", "su",
	"runas", "kill", "taskkill", "tasklist", "ps", "top", "shutdown", "reboot", "format", "diskpart", "reg",
	"regedit", "wmic", "sc", "net", "schtasks", "cron", "crontab", "eval", "exec", "source", "start", "open",
	"explorer", "notepad", "vim", "nano", "git", "npm", "pip", "docker", "kubectl", "apt", "yum", "brew", "msfconsole",
	"hydra", "john", "hashcat", "sqlmap", "nikto", "mimikatz",
]


static func command_keys() -> PackedStringArray:
	var keys: Array = TABLE.keys()
	keys.sort()
	return PackedStringArray(keys)
