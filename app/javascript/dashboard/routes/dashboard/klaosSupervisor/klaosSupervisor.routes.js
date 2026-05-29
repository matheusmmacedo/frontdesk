import { frontendURL } from '../../../helper/URLHelper';
import AgentsPanel from './AgentsPanel.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/klaos-supervisor/agents'),
      name: 'klaos_supervisor_agents',
      component: AgentsPanel,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
