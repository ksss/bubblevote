// tab manager
var Tab = {
  updateCurrentTab: function () {
    chrome.tabs.getSelected(null, function(t) {
      chrome.windows.getCurrent(function(w) {
        if (t && w && w.id == t.windowId) {
          Tab.updateTabById(t.id);
        }
      });
    });
  },
  updateTabById: function (tabId) {
    chrome.tabs.get(tabId, function(tab){
      Tab.updateTab(tab);
    });
  },
  updateTab: function (tab) {
    Tab.updateCounter(tab);
  },
  updateCounter: function (tab) {
    if (tab && tab.url && tab.url.indexOf('http') === 0) {
      var url = 'http://localhost:9292/api/votes?url=' + encodeURIComponent(tab.url);
      Cache.counter.get(url).next(function(response){
        if (response) {
          var res = JSON.parse(response.responseText);
          Tab.updateBadge(tab.id, res);
        }
      });
    }
  },
  updateBadge: function (tabId, res) {
    if (res.status === 'ok') {
      var count = 0 + res.vote.up + res.vote.down;
      chrome.browserAction.setBadgeText({text:'' + count, tabId:tabId});
      chrome.browserAction.setBadgeBackgroundColor({color:[200,0,200,200], tabId:tabId}); 
    }
  }
};

chrome.tabs.onSelectionChanged.addListener(function(tabId){
  Tab.updateCurrentTab();
});
chrome.tabs.onUpdated.addListener(function(tabId, opt){
  if (opt.status === 'loading') {
    Tab.updateTabById(tabId);
  }
});