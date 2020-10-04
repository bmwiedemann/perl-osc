package osc;
use LWP::UserAgent ();
use Net::Netrc;

our ($apibase, $user, $password);
sub init() {
    $apibase='api.opensuse.org';
    my $mach = Net::Netrc->lookup($apibase) or die "no entry for $apibase found in ~/.netrc";
    ($user, $password) = $mach->lpa;
    die unless $user;
    die unless $password;
    our $UA = LWP::UserAgent->new(
        requests_redirectable=>[],
        parse_head=>0,
        timeout=>9,
        agent=>"bmwiedemann/perl-osc-0.01",
        keep_alive => 1);
}

# makeurl(['source', 'openSUSE:Factory', 'zstd'], {'rev'=> '2', 'expand'=> 1})
sub makeurl($;$)
{
    my($pathparts, $opts) = @_;
    $opts||={};
    my $p = "/".join("/", @$pathparts);
    if(keys(%$opts)) {
        $p.="?".join("&", map { "$_=$opts->{$_}" } sort keys %$opts);
    }
    return $p;
}

sub apireq($$)
{
    my ($method, $path) = @_;
    my $request = HTTP::Request->new($method, "https://$user:$password\@$apibase$path");
    my $response = $UA->request($request);
    if($response->code != 200) {die "need to handle code $response->code for $path ?"}
    return $response->content;
}

sub apiget($) {apireq('GET', shift)}

1;
