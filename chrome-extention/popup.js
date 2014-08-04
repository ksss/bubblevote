var app_domain = 'localhost:9292';
var root_url = 'http://' + app_domain;
var auth_url = root_url + '/api/auth';
var votes_url = root_url + '/api/votes';
var detail_url = root_url + '/api/detail';
var user;
var tab;
var BG = chrome.extension.getBackgroundPage();

function load_count () {
  $.get(detail_url + '?url=' + tab.url).done(function(res){
    if (res.status == 'ok') {
      debug(res.detail);
      user = res.user;
    }
  });
};
chrome.tabs.getSelected(null, function(t){
  tab = t;
  load_count();
});

function debug (value) {
  $('#debug').html(JSON.stringify(value));
}
$(function () {
  var $post_votes_up = $('#post-votes-up');
  var $post_votes_down = $('#post-votes-down');

  $post_votes_up.on('click', function(){
    var data = {url:tab.url, method:'up', title:tab.title, favIconUrl:tab.favIconUrl, apisecret:user.apisecret};
    $.post(votes_url, data).done(function(res){
      var count = res.vote.up + res.vote.down;
      debug(res);
      BG.Tab.updateBadge(tab.id, res);
      BG.Cache.set(tab.url, count);
    })
  });

  $post_votes_down.on('click', function(){
    var data = {url:tab.url, method:'down', title:tab.title, favIconUrl:tab.favIconUrl, apisecret:user.apisecret};
    $.post(votes_url, data).done(function(res){
      debug(res);
    })
  });
});