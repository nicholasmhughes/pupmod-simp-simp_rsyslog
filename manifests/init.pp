# Set up Rsyslog on your system
#
# By default, this only sets up the system as a local Rsyslog server with no
# outside connectivity allowed.
#
# If you set the ``$is_server`` parameter, you will set this system up as a log
# server able to receive input from external systems. Restriction of this input
# is controlled by the `::rsyslog` class and the parameters there should be
# evaluated if you do not agree with the defaults.
#
# If you include the ``::simp_rsyslog::forward`` class, your system will send
# its security relevant logs (by default) to the specified ``$log_servers`` and
# ``$failover_log_servers``.
#
# ------------------------------------------------------------------------
#
# > **WARNING**
# >
# > Be **VERY** careful when setting your ``log_servers`` and
# > ``failover_log_servers`` Arrays!
# >
# > There is **no** foolproof way to detect if you are setting your local log
# > server as part of the Array. If you do this, you may end up with infinite log
# > loops that fill your log server's disk space within minutes.
# >
# > **WARNING**
#
# ------------------------------------------------------------------------
#
# This module is a component of the System Integrity Management Platform, a
# managed security compliance framework built on Puppet.
#
# This module is a SIMP Profile and is not meant to be used outside of the SIMP
# ecosystem. It **may** work, but may also require a large number of additional
# SIMP components to function properly.
#
# @see https://simp-project.com SIMP Homepage
#
# @param is_server
#   Configure the system as a log server for remote hosts
#
# @param forward_logs
#   Configure the system to forward the logs specified in the
#   ``$simp_rsyslog::security_relevant_logs`` variable
#
# @param log_servers
#   The log servers to which to send remote logs
#
#   * If set logs will be sent, in parallel, to all of these servers
#
# @param failover_log_servers
#   Failover log servers to use if the primaries go down
#
# @param default_logs
#   The logs that should be collected as security relevant to this system.
#
#   * All rules will be combined with a logical ``OR``
#
#   * If you set this yourself, you will override *ALL* defaults. If you want
#     to merge in entries, simply use the ``log_collection`` parameter.
#
# @param log_collection
#   Merge into ``$default_logs`` to set the
#   ``$simp_rsyslog::security_relevant_logs`` variable.
#
# @option log_collection
#   ``programs`` logged daemon names
#
# @option log_collection
#   ``facilities`` syslog facilities
#
# @option log_collection
#   ``priorities`` syslog priorities
#
# @option log_collection
#   ``msg_starts`` strings the message starts with
#
# @option log_collection
#   ``msg_regex`` regular expression match on the message
#
# @param log_openldap
#   Collect all OpenLDAP logs
#
#   * **WARNING** these logs are particularly verbose
#
# @param log_local
#   Write all logs to the filesystem at ``local_target``
#
# @param local_target
#   Path on the filesystem to which to write all logs that this module collects
#
# @param collect_everything
#   Set a ``*.*`` rule in Rsyslog that matches **all** logs on the system
#
#   * This overrides **any other rules** that are specified
#
#   * This is primarily meant for remote logging where all data is required
#
#   * It is **highly** recommended that you set ``log_local`` to ``false`` if
#     you are collecting all entries. Otherwise, you run a high risk of
#     overwhelming your filesystem.
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class simp_rsyslog (
  Boolean                     $is_server            = false,
  Boolean                     $forward_logs         = false,
  Array[String]               $log_servers          = simplib::lookup('simp_options::syslog::log_servers', { 'default_value' => [] }),
  Array[String]               $failover_log_servers = simplib::lookup('simp_options::syslog::failover_log_servers', { 'default_value' => [] }),
  Hash[String, Array[String]] $log_collection       = {},
  Hash[
    Enum[
      'programs',
      'facilities',
      'msg_starts',
      'msg_regex'
    ],
    Array[String]
  ]                           $default_logs         = {

    'programs'   => [ 'sudo', 'sudosh', 'yum', 'auditd', 'audit', 'systemd', 'crond' ],
    'facilities' => [ 'cron.*', 'authpriv.*', 'local6.*', 'local7.warn', '*.emerg'],
    'msg_starts' => ['IPT:'],
    'msg_regex'  => []
  },
  Boolean                     $log_openldap         = false,
  Boolean                     $log_local            = true,
  Stdlib::Absolutepath        $local_target         = '/var/log/secure',
  Boolean                     $collect_everything   = false
) {

  if $log_openldap {
    $_openldap_logs = {
      'programs'   => [ 'slapd' ],
      'facilities' => [ 'local4' ]
    }
  }
  else {
    $_openldap_logs = {}
  }

  if $collect_everything {
    $security_relevant_logs = "prifilt('*.*')"
  }
  elsif !empty($log_collection) {
    $security_relevant_logs = simp_rsyslog::format_options(
      deep_merge($default_logs, $_openldap_logs, $log_collection)
    )
  }
  else {
    $security_relevant_logs = simp_rsyslog::format_options(
      deep_merge($default_logs, $_openldap_logs)
    )
  }

  include '::rsyslog'
  include '::logrotate'

  if $log_local {
    contain '::simp_rsyslog::local'
  }

  if $forward_logs {
    contain '::simp_rsyslog::forward'
  }

  if $is_server {
    contain '::simp_rsyslog::server'
  }
}
