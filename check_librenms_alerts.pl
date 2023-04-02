#!/usr/bin/perl -w
# nagios: -epn

use strict;
use warnings;
use Getopt::Std;
use LWP;
use JSON::XS;
use Time::HiRes qw(gettimeofday tv_interval);
use Data::Dumper;

sub VERSION_MESSAGE {#{{{

	print "$0 v1.0.0\n";

}#}}}

sub HELP_MESSAGE {#{{{

	print "Usage: $0 [OPTIONS...]\n";
	print "\n";
	print "-h	librenms host (mandarory, eg.: https://librenms.org or http://librenms.org or librenms.org; defaults to https if not specified)\n";
	print "-s	skip ssl check (optional)\n";
	print "-t	token (mandatory, your api token - https://docs.librenms.org/API/#tokens)\n";
	print "-d	device_id filter (optional, comma separated device_ids, use negative ids to skip)\n";
	print "-r	rule_id filter (optional, comma separated rules_ids, use 'a' for all and negative ids to skip; default 'a')\n";
	print "-a	dump all data (optional, for debuging purposes)\n";
	print "-v	verbose level (0=none, 1=count info, 2=detailed info; default 1)\n";

	return '';
}#}}}

sub resource_select {#{{{
	my $ua = shift;
	my $url = shift;

	my $req = HTTP::Request->new(GET => $url);
	my $resp = $ua->request($req);

	if ( !$resp->is_success() ) {
		print $resp->error_as_HTML;
		die "resource_select error: $url";
	}

	my $content_json = $resp->content;
	my $objects = JSON::XS->new->decode($content_json);

	return $objects;
}#}}}

sub api_select {#{{{
	my $ua = shift;
	my $api_url = shift;
	my $resource = shift;

	my $r = resource_select($ua, $api_url . $resource);

	return $r;
}#}}}

sub api_result_array_to_hash {#{{{
	my $elements = shift;

	my $r = {};

	foreach my $element ( @{$elements} ) {
		my $id = $element->{id};
		my $name = $element->{name};

		$r->{$id}->{name} = $name;
	}

	return $r;
}#}}}

sub main {#{{{

	my $t0 = [gettimeofday()];
	my $opts = {};
	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	getopts('h:t:d:r:asv:', $opts);

	my $api_url_plain = $opts->{h} // die HELP_MESSAGE() . "\n";
	my $token = $opts->{t} // die HELP_MESSAGE() . "\n";
	my $device_filter = $opts->{d};
	my $rule_filter = $opts->{r} // 'a';
	my $is_dump_all_data = $opts->{a};
	my $is_skip_ssl_check = $opts->{s};
	my $verbose_level = $opts->{v} // 1;
	my $api_v = '/api/v0/';

	if ( $api_url_plain !~ /^http[s]:\/\// ) {
		$api_url_plain = "https://$api_url_plain";
	}

	my $api_url = $api_url_plain . $api_v;

	my $headers = HTTP::Headers->new(
		'X-Auth-Token' => $token,
	);

	my $ua = LWP::UserAgent->new();
	$ua->default_headers($headers);
	$ua->env_proxy();
	if ( $is_skip_ssl_check ) {
		$ua->ssl_opts(verify_hostname => 0);
		$ua->ssl_opts(SSL_verify_mode => 0x00);
	}

	my $rules = api_select($ua, $api_url, 'rules/');
	my $rules_map = api_result_array_to_hash($rules->{rules});

	my $rule_ids = {};
	map {
		if ( $_ eq 'a' ) {
			foreach my $rule_id ( keys %{$rules_map} ) {
				$rule_ids->{$rule_id} = 1;
			}
		} elsif ( $_ gt 0 ) {
			$rule_ids->{$_} = 1;
		} elsif ( $_ lt 0 ) {
			delete $rule_ids->{-$_};
		} else {
			die "Invalid rule filter: [$_]\n";
		}
	} split(',', $rule_filter // '');

	my $device_ids = {};
	map { $device_ids->{$_} = 1 } split(',', $device_filter // '');

	my $devices;
	if ( $device_filter || $is_dump_all_data ) {
		$devices = api_select($ua, $api_url, 'devices/');
	}

	my $alerts = api_select($ua, $api_url, 'alerts/');

	if ( $is_dump_all_data ) {
		print Dumper($alerts, $devices, $rules);
		return 0;
	}

	my $all_count = 0;
	my $warn_count = 0;
	my $crit_count = 0;
	my $output_detail_map = {};

	foreach my $alert ( @{$alerts->{alerts}} ) {
		my $device_id = $alert->{device_id};
		if ( $device_filter && !$device_ids->{$device_id} ) {
			next;
		}
		my $rule_id = $alert->{rule_id};
		if ( $rule_filter && !$rule_ids->{$rule_id} ) {
			next;
		}

		$output_detail_map->{rule_id}->{$rule_id}++;
		$all_count++;
		next if $alert->{state} != 1;
		if ( $alert->{severity} eq 'critical' ) {
			$crit_count++;
		} elsif ( $alert->{severity} eq 'warning' ) {
			$warn_count++;
		}
	}

	my $r;
	my $output_info = '';
	if ( $verbose_level > 0 ) {
		$output_info = "WARNINGS: $warn_count - CRITICALS: $crit_count - ALL: $all_count";
		if ( $verbose_level == 2 ) {
			foreach my $rule_id ( sort keys %{$output_detail_map->{rule_id}} ) {
				my $rule_name = $rules_map->{$rule_id}->{name};
				my $count = $output_detail_map->{rule_id}->{$rule_id};
				$output_info .= " [$rule_name: $count]";
			}
		}
	}

	my $t1 = [gettimeofday()];
	$output_info .= sprintf(" [%3.2f ms]", tv_interval($t0, $t1));

	if ( $crit_count > 0 ) {
		print "CRITICAL - $output_info\n";
		$r = 2;
	} elsif ( $warn_count > 0 ) {
		print "WARNING - $output_info\n";
		$r = 1;
	} else {
		print "OK - $output_info\n";
		$r = 0;
	}

	return $r;
}#}}}

exit main(@ARGV);
