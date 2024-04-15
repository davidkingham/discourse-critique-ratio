import { withPluginApi } from 'discourse/lib/plugin-api';

function initializeCritiqueRatio(api) {
  api.decorateWidget('poster-name:after', decorator);
}

function decorator(helper) {
  const user = helper.getModel();
  if (!user || !user.critique_ratio) {
    return;
  }

  return helper.h('span.critique-ratio', user.critique_ratio);
}

export default {
  name: 'critique-ratio',
  initialize() {
    withPluginApi('0.8.31', initializeCritiqueRatio);
  }
};
