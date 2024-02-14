//= require rails-ujs

window.init = function(){
  $('form').attr('autocomplete', 'off');

  var alerts = $(".alert.flash")
  setTimeout(function(){
    alerts.fadeOut();
  }, 8000);

  $(".table-sortable").tablesorter();
};

$(function(){
  window.init();
});
