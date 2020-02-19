package VoiceRSS_TTS;
use LWP::UserAgent;
use strict;

my $validate = sub {
	my ($settings) = @_;
	
	if (!$settings) { die 'The settings are undefined'; }
	if (!$settings->{'key'}) { die 'The API key is undefined'; }
	if (!$settings->{'src'}) { die 'The text is undefined'; }
	if (!$settings->{'hl'}) { die 'The language is undefined'; }
};

my $buildRequest = sub {
	my ($settings) = @_;
	
	return [
		key => ($settings->{'key'}) ? $settings->{'key'} : '',
		src => ($settings->{'src'}) ? $settings->{'src'} : '',
		hl => ($settings->{'hl'}) ? $settings->{'hl'} : '',
		r => ($settings->{'r'}) ? $settings->{'r'} : '',
		c => ($settings->{'c'}) ? $settings->{'c'} : '',
		f => ($settings->{'f'}) ? $settings->{'f'} : '',
		ssml => ($settings->{'ssml'}) ? $settings->{'ssml'} : '',
		b64 => ($settings->{'b64'}) ? $settings->{'b64'} : ''
	];
};

my $request = sub {
	my ($settings) = @_;
	my $result = {
		'error' => undef,
		'response' => undef
	};
	
	my $url = ($settings->{'ssl'}) ? 'https://api.voicerss.org/' : 'http://api.voicerss.org/';
	my $params = $buildRequest->($settings);
	my $ua = LWP::UserAgent->new();
	my $response = $ua->post($url, $params);
	
	if ($response->is_success) {
		my $content = $response->content;
		
		if (index($content, 'ERROR') == 0) {
			$result->{'error'} = $content;
		} else {
			$result->{'response'} = $content;
		}
	} else {
		$result->{'error'} = $response->message;
	}

	return $result;
};

sub speech {
	my ($settings) = @_;
	
	$validate->($settings);
	return $request->($settings);
}

1;

