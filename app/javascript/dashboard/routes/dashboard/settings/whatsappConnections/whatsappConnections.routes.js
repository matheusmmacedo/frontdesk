import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';

const Index = () => import('./Index.vue');
const ConnectionDetail = () => import('./ConnectionDetail.vue');
const NewMetaConnection = () => import('./NewMetaConnection.vue');
const NewEvolutionConnection = () => import('./NewEvolutionConnection.vue');

export default {
  routes: [
    {
      path: frontendURL(
        'accounts/:accountId/settings/whatsapp-connections'
      ),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'whatsapp_connections_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'meta/new',
          name: 'whatsapp_connections_new_meta',
          component: NewMetaConnection,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: 'evolution/new',
          name: 'whatsapp_connections_new_evolution',
          component: NewEvolutionConnection,
          meta: {
            permissions: ['administrator'],
          },
        },
        {
          path: ':connectionId',
          name: 'whatsapp_connections_detail',
          component: ConnectionDetail,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
