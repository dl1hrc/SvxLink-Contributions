#!/usr/bin/perl

# Zusatz zum Tcl-Modul fuer das SvxLink-Projekt von Tobias Blomberg SM0SVX
#
# V0.1 - 04.01.2020 Adi Bier <DL1HRC at gmx.de>
#
# Nimmt via postfix und procmail eine eMail vom DWD entgegen und erstellt 
# daraus eine von HTML-Steuerzeichen bereinigte Textdatei sowie eine 
# entsprechende WAV-Datei im Spool-Verzeichnis /var/spool/svxlink/weatherinfo
#
# Zum Funktionieren ist ein VoiceRSS-Api-Key erforderlich, den man über die 
# Webseite http://www.voicerss.org/ kostenlos bekommt. 350 Anfragen täglich 
# sind kostenlos möglich.
#
# Weiterhin muss leider sox installiert sein, da die von VoiceRSS gelieferten 
# WAV's eine Fehlermeldung bzgl chunksize liefern.

require voicerss_tts;
use strict;
use POSIX qw(strftime);
use Digest::MD5 qw(md5 md5_hex md5_base64);
use MIME::Decoder;
use MIME::Parser;
use MIME::QuotedPrint;
use File::Copy;
use Net::HTTP;

################################################################################
# Konfigurationsdaten und Verzeichnisse
################################################################################
my $DEBUG    = 1;  # 0 oder 1
my $apikey   = "hier VoiceRSS-Api-Key eintragen";
my $lang     = "de-de";
my $call     = "DL1ABC"; # hier RepeaterCall eintragen
my $wavetype = "16khz_16bit_mono";
my $wavedir  = "/usr/share/svxlink/sounds/de_DE/Announcement";
my $infofile = "$wavedir/$call";
my $logfile  = "/tmp/announcement-$call.log";
my $soxdir   = "/tmp";
my $tempmail = "/tmp/$call.tmpmail";
################################################################################

my @in = <>;
my $inhalt = join("",@in);
&save_mail($inhalt);

# Mime Encoding bearbeiten
my $top_entity = &parse_MIME_Stream("$tempmail");

# Mailheader bearbeiten
&handle_Mail_header($top_entity);

# .info-Files erstellen und wav-Datei generieren
&walk($top_entity);

unlink("$tempmail");
exit;

################################################################################
# Subs
################################################################################
#
# eMail durchgehen und Body extrahieren
#
sub walk #(Entity)
{
  my $entity = shift if @_;
  return unless defined $entity;

  my $head = $entity->head();
  &writelog("Head: $head");

   # mehrteilige Nachricht
  if ($head->mime_type() =~ m/multipart/i)
  {
    my $i;
    my $num_alt_parts = $entity->parts();
    my $current_entity;

    # alle Teile der Nachricht rekursiv abarbeiten
    for ($i = 0; $i < $num_alt_parts; $i++)
    {
      $current_entity = $entity->parts($i);
      &walk($current_entity);
      return;
    }
  }
  else
  {   # einteilige Nachricht
    &handle_head($head) if (defined $head);
    my $body = $entity->bodyhandle();

    if (defined $body)
    {
      # Body gefunden
      my $Content = $body->as_string;
      my $wav;

      my @infos = &check_filter($Content);
      my $ti = $infos[0];
      $wav = &make_wave($ti);
      return;
    }
  }
}

# (Header)
sub handle_head {
  my $current_head = shift;
  $current_head->decode;
  $current_head->unfold;

  # Headerinformationen ausgeben
  print "MIME-Type:           ", $current_head->mime_type(), "\n";
  print "Encoding:            ", $current_head->mime_encoding(), "\n";
  print "Content-type:        ", $current_head->mime_attr('content-type'), "\n";
  print "Charset:             ", $current_head->mime_attr('content-type.charset'), "\n";
  print "Content-Disposition: ", $current_head->mime_attr('content-disposition'), "\n";
  print "Filename:            ", $current_head->recommended_filename(), "\n";
}

sub handle_body {
  my $current_body = shift;
  if (defined($current_body->path)) 
    {   # data is on disk:
    print "Data is stored on Disk: ", $current_body->path() , "\n";
    print '-' x 60 . "\n\n";

    # Your code goes here
    }
  else {
    # How to get the data
    # $Content = $current_body->as_string;
    # @Content = $current_body->as_lines();
    # $current_body->print(\*OUTSTREAM);
    # Your code goes here
  }
}


# (Eingabedatei)
sub parse_MIME_Stream
{
  my $file = shift;
  my $parser = '';

  die "NO FILE  $!" unless defined $file;

  # Neues Parser-Objekt
  # Daten auf Festplatte speichern
  $parser = MIME::Parser->new();
  $parser->output_to_core('NONE');
#  $parser->output_dir($wavedir);
#  $parser->output_prefix($call);

  open(INPUT,$file) or die $!;
  my $top_entity = $parser->read(\*INPUT);
  close(INPUT) or die $!;

  return $top_entity;
}


#
# prüfen auf bestimmte Phrasen und Anpassung zur besseren Ausgabe
#
sub check_filter {

# Meldung der zustaendigen Behoerde Bevoelkerungswarnung: Grossbrand Postleitzahl: \
# 06108 gueltig ab sofort Ausgabezeitpunkt: 15.1.2018, 17:13 Uhr \
# ------------------------------------------------------------------------ \
# Stadt Halle(Saale) meldet: Warnung Grossbrand. Details: Auf Grund eines \
# Brandes, Fenster und Tueren geschlossen halten ! \
# Weitere Hinweise: Schalten Sie Lueftungs- und Klimaanlagen ab. Schalten \
# Sie Rundfunk und Fernsehen an. -\
# ----------------------------------------------------------------------- \
# Bitte schliessen Sie sofort Fenster und Tueren. Diese Nachricht wurde \
# von Katwarn im Auftrag der oertlich zustaendigen Behoerde versendet. \
# Fuer Rueckmeldungen und Anregungen nutzen Sie bitte info@katwarn.de. \
# DocId: 1516032784021.0@kwrn

  my $inhalt = $_[0];
  my $ok;

  $inhalt =~ s/\n/ /g;
  $inhalt =~ s/\s{2,}/ /g;

  $inhalt =~ s/Ü/Ue/g;
  $inhalt =~ s/Ö/Oe/g;
  $inhalt =~ s/Ä/Ae/g;
  $inhalt =~ s/ß/ss/g;
  $inhalt =~ s/ü/ue/g;
  $inhalt =~ s/ö/oe/g;
  $inhalt =~ s/ä/ae/g;
  $inhalt =~ s/\s\!/\!/g;
  $inhalt =~ s/\sbzw\.\s/\sbeziehungsweise\s/g;

  my @meldungen;

  # Daten zur Ausgabe vorhanden?
  if ($inhalt gt " ")
  {
    push (@meldungen, $inhalt);
    &writelog("Inhalt in sub check_filter: $inhalt");
  }
  return @meldungen;
}

# zum Debuggen mitloggen
sub writelog {
#  if (!$DEBUG) {return;}
  my $now = strftime "%d.%m.%Y %H:%M:%S", localtime;
  open(LOGFILE,">>$logfile");
    print LOGFILE "$now: $_[0]\n";
  close(LOGFILE);
}


#
# temporaere Speicherung der eingehenden eMail fuer die Weiterverarbeitung
#
sub save_mail {
  open (TMP,">$tempmail");
    print TMP $_[0];
  close(TMP);
}


sub handle_Mail_header {
  my $entity = shift;
  # $entity->print_header(\*STDOUT);

  my $head = $entity->head();
  $head->decode;
  $head->unfold;

  # Mail-Nachrichten-Header-Felder ausgeben
  print "Subject:         ", $head->get('Subject'), "\n";
  print "From:            ", $head->get('From'), "\n";
  print "Sender:          ", $head->get('Sender'), "\n";
  print "Return-Path:     ", $head->get('Return-Path'), "\n";
  print "Date:            ", $head->get('Date'), "\n";
  print "To:              ", $head->get('To'), "\n";
  print "Organization:    ", $head->get('Organization'), "\n";
  print "Return-Path:     ", $head->get('Return-Path'), "\n";
  print "Status:          ", $head->get('Status'), "\n";
  print "Message-ID:      ", $head->get('Message-ID'), "\n";
  print "Precedence:      ", $head->get('Precedence'), "\n";
  print "References:      ", $head->get('References'), "\n";
  print "X-Priority:      ", $head->get('X-Priority'), "\n";
  print "X-Mailer:        ", $head->get('X-Mailer'), "\n";
  print "X-Virus-Scanned: ", $head->get('X-Virus-Scanned'), "\n";
  print "Ref. Count:      ", $head->count('References'), "\n";
  if ($head->count('References') == 0) 
    { print "New thread\n"; } 
  else 
    { print "Reply\n"; }

  print "Number of Hops: " , $head->count('Received') , "\n";
  my @hops = $head->get_all('Received');
  for (my $x = 0; $x <= $#hops; $x++) 
  {
    print "Mail-Host [" , $x + 1, "] $hops[$x] \n";
  }
  print "\n\n";
}


#
# WAV-Datei per VoiceRSS erstellen
#
sub make_wave {
  my $input = $_[0];
  my $settings = {
    'key' => $apikey,
    'hl' => "$lang",
    'src' => "$input",
    'r' => '0',
    'c' => 'wav',
    'f' => "$wavetype",
    'ssml' => 'false',
    'b64' => 'false'
  };
  my $voice = VoiceRSS_TTS::speech($settings);
  my $checksum = md5_hex($input);
  my $inffile = "$infofile.$checksum.info";
  my $tw      = "$soxdir/$checksum.wav";
  my $wavfile = "$infofile.$checksum.wav";

  open(WAV,">$tw")||&writelog("Kann File $tw nicht oeffnen/erstellen");
    print WAV $voice->{'response'};
  close WAV;

 `/usr/bin/sox $tw -r 16000 $wavfile`;
  &writelog("WAV-File erstellt: ($tw) $wavfile");
  unlink $tw;

  open(OUT,">$inffile");
    print OUT $input;
  close(OUT);
  &writelog("INFO-File erstellt: $inffile, Inhalt: $input");

  if ($voice->{'error'}) {
    &writelog($voice->{'error'}.'\n');
  }

  chmod(0660,"$inffile");
  chmod(0660,"$wavfile");
}
