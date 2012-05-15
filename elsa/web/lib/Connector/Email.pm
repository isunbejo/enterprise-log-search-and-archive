package Connector::Email;
use Moose;
use Data::Dumper;
use MIME::Base64;
extends 'Connector';

our $Description = 'Send email';
sub description { return $Description }
sub admin_required { return 0 }

has 'query' => (is => 'rw', isa => 'Query', required => 1);

sub BUILD {
	my $self = shift;
	$self->api->log->debug('got results to alert on: ' . Dumper($self->query->results));
		
	unless ($self->query->results->total_records){
		$self->api->log->info('No results for query');
		return 0;
	}
	
	my $headers = {
		To => $self->user->email,
		From => $self->api->conf->get('email/display_address') ? $self->api->conf->get('email/display_address') : 'system',
		Subject => $self->api->conf->get('email/subject') ? $self->api->conf->get('email/subject') : 'system',
	};
	my $body = sprintf('%d results for query %s', $self->query->results->records_returned, $self->query->query_string) .
		"\r\n" . sprintf('%s/get_results?qid=%d&hash=%s', 
			$self->api->conf->get('email/base_url') ? $self->api->conf->get('email/base_url') : 'http://localhost',
			$self->query->qid,
			$self->api->get_hash($self->query->qid),
	);
	
	my ($query, $sth);
	$query = 'SELECT UNIX_TIMESTAMP(last_alert) AS last_alert, alert_threshold FROM query_schedule WHERE id=?';
	$sth = $self->api->db->prepare($query);
	$sth->execute($self->query->schedule_id);
	my $row = $sth->fetchrow_hashref;
	if ((time() - $row->{last_alert}) < $row->{alert_threshold}){
		$self->api->log->warn('Not alerting because last alert was at ' . (scalar localtime($row->{last_alert})) 
			. ' and threshold is at ' . $row->{alert_threshold} . ' seconds.' );
		return;
	}
	else {
		$query = 'UPDATE query_schedule SET last_alert=NOW() WHERE id=?';
		$sth = $self->api->db->prepare($query);
		$sth->execute($self->query->schedule_id);
	}
	
	$self->api->send_email({ headers => $headers, body => $body});
	
	# Save the results
	$self->query->comments('Scheduled Query ' . $self->query->schedule_id);
	$self->api->save_results($self->query->TO_JSON);
}

1