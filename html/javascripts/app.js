/**
 * Run application.
 */
$(function () {
    // On hash change.
    $(window).bind('hashchange', route);

    // On click without hash change.
    $('a[href^="#"]').click(function () {
        if ($(this).attr('href') === location.hash) {
            route();
        }
    });

    // On app loads.
    route();
});

/**
 * Router of application.
 */
function route() {
    var downloads = function () {
        activateLink('#downloads');
        showPanel('#panel-downloads');
    };

    var decryption = function () {
        activateLink('#decryption');
        showPanel('#panel-decrypt');
    };

    var about = function () {
        activateLink('#about');
        showPanel('#panel-about');
    };

    switch (location.hash) {
        case '':
        case '#downloads':
            downloads();
            break;

        case '#decryption':
            decryption();
            break;

        case '#about':
            about();
            break;

        // By default we get an code in hash.
        default:
            decryption();
            $('#decrypt-text').val(location.hash).trigger('autosize.resize');
            showDecryptModal();
    }
}

/**
 * Activate navbar link.
 */
function activateLink(name) {
    var nav = $('.nav');
    nav.find('li').removeClass('active');
    nav.find('a[href="' + name + '"]').parent().addClass('active');
}

/**
 *  Show panel.
 */
function showPanel(id) {
    var panel = $(id);
    panel.show();
    $('.panels .panel').not(panel).hide();
}

/**
 * Returns password of complex password/text fields.
 */
function getPassword(password) {
    var ps = password.find('input:visible').val();
    if (ps === '') {
        password.addClass('has-error');
    } else {
        password.removeClass('has-error');
    }
    return ps;
}

/**
 * Decrypt modal action.
 */
function showDecryptModal() {
    var modal = $('#modal-decrypt');
    var hint = modal.find('.hint');

    try {
        var hintText = sjcl.codec.utf8String.fromBits(sjcl.codec.base64.toBits(getParameters().adata));
        if (hintText.length !== 0) {
            hint.text(hintText);
        } else {
            hint.text('');
        }
    } catch (e) {
        hint.text('');
    }

    modal.modal();

    // TODO: Focus password input field.
}

/**
 *  Save configuration
 */

function saveConfig() {
    var fields = $('#config').serializeArray();
    $.each(fields, function (i, field) {
        var value = field.value;
        if(/^\d+$/.test(value)) {
            value = parseInt(value, 10);
        }
        config[field.name] = value;
    });
    $('#modal-config').modal('hide');
}