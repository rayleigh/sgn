JSAN.use('jquery');

var SGN;
if(!SGN) SGN = {};
if(!SGN.Login) SGN.Login = {
};

jQuery(function($) { 
    $('#login_control div.logged_out a.login').click(function() {
        $('#login_control form.login_form').slideDown();
        return false;
    });

    $("#login_control form.login_form input[value='cancel']").click(function() {
        $('#login_control form.login_form').slideUp();
        return false;
    });
});
