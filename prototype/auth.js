// Google sign-in (required) and profile, shared with Gopinath's other apps: see kolam-design-system/auth.
import { KolamAuth } from 'https://tgopinath.github.io/kolam-design-system/auth/kolam-auth.js'
KolamAuth.init({
  app: 'forge', appName: 'Forge',
  tagline: 'Save your plan and workout history to your account, so they follow you between devices.',
  fields: [
    { key: 'goal', label: 'Goal', type: 'select', options: [['strength', 'Get stronger'], ['muscle', 'Build muscle'], ['fat-loss', 'Lose fat'], ['fitness', 'General fitness']] },
    { key: 'level', label: 'Level', type: 'select', options: [['beginner', 'Beginner'], ['intermediate', 'Intermediate'], ['advanced', 'Advanced']] },
    { key: 'units', label: 'Units', type: 'select', options: [['kg', 'Kilograms'], ['lb', 'Pounds']] },
  ],
  sync: ['forge-prototype-v1', 'forge-proto-theme'],
})
