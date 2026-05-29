import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/klaos-meta-health'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'klaos_meta_health_index',
          component: Index,
          meta: {
            featureFlag: null,
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
