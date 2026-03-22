import { frontendURL } from '../../../../helper/URLHelper';
import { ROLES } from 'dashboard/constants/permissions.js';

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
      name: 'whatsapp_connections_index',
      meta: {
        permissions: [ROLES.ADMINISTRATOR],
      },
      component: Index,
    },
    {
      path: frontendURL(
        'accounts/:accountId/settings/whatsapp-connections/meta/new'
      ),
      name: 'whatsapp_connections_new_meta',
      meta: {
        permissions: [ROLES.ADMINISTRATOR],
      },
      component: NewMetaConnection,
    },
    {
      path: frontendURL(
        'accounts/:accountId/settings/whatsapp-connections/evolution/new'
      ),
      name: 'whatsapp_connections_new_evolution',
      meta: {
        permissions: [ROLES.ADMINISTRATOR],
      },
      component: NewEvolutionConnection,
    },
    {
      path: frontendURL(
        'accounts/:accountId/settings/whatsapp-connections/:connectionId'
      ),
      name: 'whatsapp_connections_detail',
      meta: {
        permissions: [ROLES.ADMINISTRATOR],
      },
      component: ConnectionDetail,
    },
  ],
};
