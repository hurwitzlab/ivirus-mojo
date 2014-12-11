package IVirus::Controller::Feedback;

use IVirus::DB;
use Captcha::reCAPTCHA;
use Data::Dump 'dump';
use Email::Valid;
use HTML::LinkExtractor;
use IVirus::Config;
use Mail::Sendmail;
use Mail::SpamAssassin;
use Mojo::Base 'Mojolicious::Controller';
use Readonly;

Readonly my $DOUBLE_NEWLINE => "\n\n";
Readonly my $COMMENTS_MAX   => 10_000;
Readonly my $MAX_URLS       => 5;
Readonly my $RECIPIENTS     
    => 'project-6969156-76a72db1651b0b95588548e9@basecamp.com';

# -------------------------------------------------------
sub captcha_keys {
    my $self  = shift;
    my $conf  = $self->config;
    my $cfile = $conf->{'captcha_conf'} || die 'No Captcha conf';
    my $cconf = IVirus::Config->new(filename => $cfile);
    my $keys  = $cconf->get('keys') || die 'No Captcha keys';

    if (ref $keys eq 'HASH') {
        return $keys;
    }
    else {
        die 'Bad Captcha key format';
    }
}

# ----------------------------------------------------------------------
sub form {
    my $self         = shift;
    my $captcha_keys = $self->captcha_keys;
    my $captcha      = Captcha::reCAPTCHA->new;
    my $captcha_html = $captcha->get_html($captcha_keys->{'public'});

    $self->respond_to(
        json => sub {
            $self->render( json => 'Send an email to "ivirus@ivirus.us"' );
        },

        html => sub {
            $self->layout('default');
            $self->render(title => 'Feedback', captcha => $captcha_html);
        }
    );
}

# ----------------------------------------------------------------------
sub submit {
    my $self = shift;
    my $req  = $self->req;

    my @errors;
    for my $field (qw[ subject user_name user_email ]) {
        my $val = $req->param($field) || '';
        if ( $val =~ /[\r\n]|(\\[rn])/ ) {
            push @errors, "Field $field '$val' looks like a spam attack.";
        }
    }

    my $problem_url    = $req->param('refer_from')   || '';
    my $user_name      = $req->param('user_name')    || '';
    my $user_email     = $req->param('user_email')
            or push @errors, 'No email address';
    my $comments       = $req->param('comments')
            or push @errors, 'No comments';
    my $captcha_guess  = $req->param('recaptcha_challenge_field')
            or push @errors, 'Internal CAPTCHA error. Please try again.';
    my $captcha_response = $req->param('recaptcha_response_field')
            or push @errors, 'No text for image';

    if ( $user_email &&
         !Email::Valid->address( -address => $user_email, -mxcheck=> 1 )
    ) {
        push @errors, "Invalid email address '$user_email'";
    }

    #
    # if they guessed something, and it doesn't match, then toss an error
    # if there was no guess, we've already noted that they didn't give us
    # one up above.
    #
    my $captcha_keys = $self->captcha_keys;
    my $captcha      = Captcha::reCAPTCHA->new;
    my $result       = $captcha->check_answer(
        $captcha_keys->{'private'}, 
        $self->req->headers->header('X-Forwarded-For'), # remote IP
        $captcha_guess, 
        $captcha_response
    );

    if (!$result->{'is_valid'}) {
        push @errors, 'Bad Captcha response';
    }

    $self->layout('default');

    if (@errors) {
        $self->render( errors => \@errors );
    }
    else {
        my $lx = HTML::LinkExtractor->new;
        $lx->parse(\$comments);
        my $subject = sprintf('Site Feedback: %s', 
            $req->param('subject') || 'No subject',
        );

        my $user         = sprintf '%s%s',
            $user_name   ? $user_name : '',
            " <$user_email>"
        ;

        my $num_links = scalar @{ $lx->links };
        my $spamtest  = Mail::SpamAssassin->new;
        my $mail      = $spamtest->parse($comments);
        my $status    = $spamtest->check($mail);
        my $is_spam   = $status->is_spam;

        if (!$is_spam) {
            if (
                   ( $num_links > $MAX_URLS )
                || ( $subject =~ /@/ )
                || ( $problem_url =~ /@/ )
            ) {
                $is_spam = 1;
            }
        }

        if (length($comments) > $COMMENTS_MAX) {
            $comments = substr($comments, 0, $COMMENTS_MAX);
            $comments .= "\n[MESSAGE TRUNCATED]";
        }

        my $message = join $DOUBLE_NEWLINE,
            "Subject : $subject",
            "URL     : $problem_url",
            "Name    : $user_name",
            "Email   : $user_email",
            'Comments: ',
            $comments,
        ;

        my %mail_args  = (
            'Subject'  => "Discussion: $subject",
            'To'       => $RECIPIENTS,
            'From'     => $user_email,
            'Cc'       => $user,
            'Reply-To' => $RECIPIENTS,
        );

        sendmail(
            %mail_args,
            'Message' => $message
        ) or die $Mail::Sendmail::error;

        $self->render(
            %mail_args,
            'title'      => 'Message Received',
            'return_url' => $problem_url,
            'Message'    => $message
        );
    }
}

1;
