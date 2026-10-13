import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'Overview',
    {
      type: 'category',
      label: 'Installation',
      collapsible: false,
      items: [
        'installation/arch',
        'installation/nixos',
      ],
    },
    {
      type: 'category',
      label: 'Configure',
      collapsible: false,
      items: [
        'configure/Configure',
        {
          type: 'category',
          label: 'Compositors',
          collapsible: false,
          items: [
            'configure/compositors/hyprland',
            'configure/compositors/niri',
            'configure/compositors/sway',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'CLI',
      collapsible: false,
      items: [
        'cli/client',
        'cli/daemon',
      ],
    },
  ],
};

export default sidebars;
