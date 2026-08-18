#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require "optparse"
require "tempfile"

ACCESS_TOKEN_ENV = "ACCESS_TOKEN"
SYSLOG_SERVER_ENV = "SYSLOG_SERVER"
SYSLOG_PORT_ENV = "SYSLOG_PORT"
ACCESS_CONTROLLER_NICKNAME_ENV = "ACCESS_CONTROLLER_NICKNAME"
MEMBER_NAME_ENV = "MM_USER_NAME"
VERBS = ["sync", "users", "open", "lock", "unlock", "ssh-ping", "ping", "uptime", "backup"].freeze

def usage!
  warn "Usage: #{$PROGRAM_NAME} <action> [args]"
  warn "       #{$PROGRAM_NAME} actions"
  exit 2
end

def fetch_access_token!
  token = ENV[ACCESS_TOKEN_ENV]
  return token unless token.nil? || token.strip.empty?

  warn "#{ACCESS_TOKEN_ENV} must be set"
  exit 2
end

def read_users_from_stdin!
  raw = STDIN.read
  return [] if raw.strip.empty?

  JSON.parse(raw)
rescue JSON::ParserError => error
  warn "Failed to parse JSON from STDIN: #{error.message}"
  exit 2
end

def rewrite_users(users)
  # Transform the input array into a hash keyed by RFID.
  users.each_with_object({}) do |user, out|
    rfids = Array(user["rfids"]).map(&:to_s).map(&:strip).reject(&:empty?)
    next if rfids.empty?

    permissions = Array(user["permissions"]).map(&:to_s).map(&:strip).reject(&:empty?)
    if user["name"].to_s != "Master Event Key" and user["name"].to_s != "Jon Hannis"
      permissions.reject! { |permission| permission == "Event Host" }
    end
    permissions << "active member"
    normalized_permissions = permissions.map(&:downcase).uniq.sort

    name = user["name"].to_s

    rfids.each do |rfid|
      out[rfid] = {
        "permissions" => normalized_permissions,
        "name" => name
      }
    end
  end
end

def debug_log(message, verbose)
  return unless verbose

  warn "[debug] #{message}"
end

def parse_host_arg(host_arg)
  user, host = host_arg.to_s.split("@", 2)
  return [user, host] if host

  [nil, host_arg]
end

def external_ssh_options
  [
    "-o", "PubkeyAcceptedKeyTypes=+ssh-rsa",
    "-o", "HostKeyAlgorithms=+ssh-rsa",
    "-o", "StrictHostKeyChecking=accept-new",
    "-o", "PubkeyAcceptedAlgorithms=+rsa-sha2-256",
    "-o", "PubkeyAuthentication=yes"
  ]
end

def syslog_message(action)
  host_nickname = ENV[ACCESS_CONTROLLER_NICKNAME_ENV].to_s
  member_name = ENV[MEMBER_NAME_ENV].to_s
  "#{member_name} has #{action} #{host_nickname}"
end

def safe_filename(value)
  value.to_s.strip.gsub(/[^A-Za-z0-9._-]+/, "_")
end

def log_access_event(action, verbose)
  server = ENV[SYSLOG_SERVER_ENV].to_s
  port = ENV[SYSLOG_PORT_ENV].to_s
  args = ["logger", "-t", "accesscontrol"]
  args += ["-n", server] unless server.empty?
  args += ["-P", port] unless port.empty?
  args << syslog_message(action)
  debug_log("logger #{args.join(' ')}", verbose)

  ok = system(*args)
  return if ok

  warn "Logger command failed"
  exit 1
end

def run_ssh_commands(host_arg, access_token, commands, verbose)
  user, host = parse_host_arg(host_arg)
  debug_log("run_ssh_commands host=#{host} user=#{user.inspect}", verbose)
  ssh_options = external_ssh_options
  target = user ? "#{user}@#{host}" : host

  Tempfile.create("access_token") do |key_file|
    key_file.write(access_token)
    key_file.write("\n") unless access_token.end_with?("\n")
    key_file.flush
    key_file.chmod(0o600)

    ok = system(
      "ssh",
      *ssh_options,
      "-i", key_file.path,
      target,
      *commands
    )
    return if ok
  end

  warn "SSH command failed"
  exit 1
end

def run_ssh_command_with_input(host_arg, access_token, commands, input, verbose)
  user, host = parse_host_arg(host_arg)
  debug_log("run_ssh_command_with_input host=#{host} user=#{user.inspect}", verbose)
  ssh_options = external_ssh_options
  target = user ? "#{user}@#{host}" : host

  Tempfile.create("access_token") do |key_file|
    key_file.write(access_token)
    key_file.write("\n") unless access_token.end_with?("\n")
    key_file.flush
    key_file.chmod(0o600)

    stdout, stderr, status = Open3.capture3(
      "ssh",
      *ssh_options,
      "-i", key_file.path,
      target,
      *commands,
      stdin_data: input
    )

    return stdout if status.success?

    warn stderr.strip.empty? ? "SSH command failed" : stderr.strip
    exit 1
  end
end

def run_ssh_command_capture(host_arg, access_token, commands, verbose)
  user, host = parse_host_arg(host_arg)
  debug_log("run_ssh_command_capture host=#{host} user=#{user.inspect}", verbose)
  ssh_options = external_ssh_options
  target = user ? "#{user}@#{host}" : host

  Tempfile.create("access_token") do |key_file|
    key_file.write(access_token)
    key_file.write("\n") unless access_token.end_with?("\n")
    key_file.flush
    key_file.chmod(0o600)

    stdout, stderr, status = Open3.capture3(
      "ssh",
      *ssh_options,
      "-i", key_file.path,
      target,
      *commands
    )
    return stdout if status.success?

    warn stderr.strip.empty? ? "SSH command failed" : stderr.strip
    exit 1
  end
end

def run_ssh_command_stream_to_file(host_arg, access_token, commands, output_path, verbose)
  user, host = parse_host_arg(host_arg)
  debug_log("run_ssh_command_stream_to_file host=#{host} user=#{user.inspect}", verbose)
  ssh_options = external_ssh_options
  target = user ? "#{user}@#{host}" : host

  Tempfile.create("access_token") do |key_file|
    key_file.write(access_token)
    key_file.write("\n") unless access_token.end_with?("\n")
    key_file.flush
    key_file.chmod(0o600)

    File.open(output_path, "wb") do |output|
      IO.popen(
        [
          "ssh",
          *ssh_options,
          "-i", key_file.path,
          target,
          *commands
        ],
        "rb"
      ) do |io|
        IO.copy_stream(io, output)
      end
    end

    return if $?.success?
  end

  warn "SSH command failed"
  exit 1
end

def format_duration(total_seconds)
  seconds = Integer(total_seconds)
  units = [
    ["month", 30 * 24 * 60 * 60],
    ["day", 24 * 60 * 60],
    ["hour", 60 * 60],
    ["minute", 60],
    ["second", 1]
  ]

  parts = []
  units.each do |label, size|
    count, seconds = seconds.divmod(size)
    next if count.zero?

    parts << "#{count} #{label}#{count == 1 ? "" : "s"}"
  end

  parts = ["0 seconds"] if parts.empty?
  parts.join(", ")
end

def action_sync(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  users = read_users_from_stdin!
  rewritten_users = rewrite_users(users)
  run_ssh_command_with_input(
    host,
    access_token,
    ["sync"],
    JSON.dump(rewritten_users),
    verbose
  )
end

def action_users
  users = read_users_from_stdin!
  rewritten_users = rewrite_users(users)
  puts JSON.dump(rewritten_users)
end

def action_open(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  log_access_event("opened", verbose)
  run_ssh_commands(host, access_token, ["open"], verbose)
end

def action_lock(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  log_access_event("locked", verbose)
  run_ssh_commands(host, access_token, ["lock"], verbose)
end

def action_unlock(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  log_access_event("unlocked", verbose)
  run_ssh_commands(host, access_token, ["unlock"], verbose)
end

def action_ssh_ping(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  run_ssh_commands(host, access_token, ["ping"], verbose)
end

def action_ping(host)
  _user, hostname = parse_host_arg(host)
  ok = system("ping", "-c", "1", "-W", "5", hostname)
  exit 1 unless ok
end

def action_uptime(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  raw = run_ssh_command_capture(host, access_token, ["uptime"], verbose)
  seconds = raw.to_s.strip
  if seconds.match?(/\A\d+\z/)
    puts format_duration(seconds)
  else
    warn "Unexpected uptime response: #{seconds.inspect}"
    exit 1
  end
end

def action_backup(host, verbose)
  access_token = fetch_access_token!
  debug_log("#{ACCESS_TOKEN_ENV} length=#{access_token.length}", verbose)
  controller_name = ENV[ACCESS_CONTROLLER_NICKNAME_ENV] || host
  base_name = safe_filename(controller_name)
  timestamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
  backup_dir = "/access-backups"
  unless Dir.exist?(backup_dir)
    warn "#{backup_dir} does not exist"
    exit 1
  end
  output_path = File.join(backup_dir, "#{base_name}-#{timestamp}.tar.gz")
  run_ssh_command_stream_to_file(host, access_token, ["backup"], output_path, verbose)
  puts output_path
end

options = {
  debug: false,
  verbose: false
}

OptionParser.new do |parser|
  parser.on("-v", "--verbose", "Enable verbose logging") do
    options[:verbose] = true
  end

  parser.on("-d", "--debug", "Log all output to debug.log") do
    options[:debug] = true
  end

end.parse!(ARGV)

if options[:debug]
  debug_file = File.open("debug.log", "a")
  debug_file.sync = true
  $stdout.reopen(debug_file)
  $stderr.reopen(debug_file)
  $stdout.sync = true
  $stderr.sync = true
end

verbose = options[:verbose]
debug_log("args=#{ARGV.inspect}", verbose)
debug_log("env #{ACCESS_TOKEN_ENV}=#{ENV[ACCESS_TOKEN_ENV].inspect}", verbose)
debug_log("env #{ACCESS_CONTROLLER_NICKNAME_ENV}=#{ENV[ACCESS_CONTROLLER_NICKNAME_ENV].inspect}", verbose)
debug_log("env #{MEMBER_NAME_ENV}=#{ENV[MEMBER_NAME_ENV].inspect}", verbose)
debug_log("env #{SYSLOG_SERVER_ENV}=#{ENV[SYSLOG_SERVER_ENV].inspect}", verbose)

if ARGV.include?("actions")
  puts VERBS.join("\n")
  exit 0
end

action = ARGV.shift
usage! if action.nil? || action.strip.empty?

case action
when "sync"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_sync(host, verbose)
when "users"
  action_users
when "open"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_open(host, verbose)
when "lock"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_lock(host, verbose)
when "unlock"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_unlock(host, verbose)
when "ssh-ping"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_ssh_ping(host, verbose)
when "ping"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_ping(host)
when "uptime"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_uptime(host, verbose)
when "backup"
  host = ARGV.shift
  usage! if host.nil? || host.strip.empty?

  action_backup(host, verbose)
else
  warn "Unknown action: #{action}"
  usage!
end
