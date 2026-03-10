import { LocalStorage } from 'shared/helpers/localStorage';
import { LOCAL_STORAGE_KEYS } from 'dashboard/constants/localStorage';

export const setColorTheme = isOSOnDarkMode => {
  const selectedColorScheme =
    LocalStorage.get(LOCAL_STORAGE_KEYS.COLOR_SCHEME) || 'auto';

  document.body.classList.remove('dark', 'whatsapp', 'whatsapp-dark');

  if (selectedColorScheme === 'whatsapp') {
    document.body.classList.add('whatsapp');
    document.documentElement.style.setProperty('color-scheme', 'light');
  } else if (selectedColorScheme === 'whatsapp-dark') {
    document.body.classList.add('whatsapp', 'whatsapp-dark');
    document.documentElement.style.setProperty('color-scheme', 'dark');
  } else if (
    (selectedColorScheme === 'auto' && isOSOnDarkMode) ||
    selectedColorScheme === 'dark'
  ) {
    document.body.classList.add('dark');
    document.documentElement.style.setProperty('color-scheme', 'dark');
  } else {
    document.documentElement.style.setProperty('color-scheme', 'light');
  }
};
