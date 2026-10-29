import { COUNT_AGENCIES } from './count-agencies.mjs';
import { templateDates } from './comptage.mjs';

// The existing database stores the route as a stable suffix on the agency name.
// Do not change this suffix: doing so would orphan previously recorded routes.
export function splitCountAgencyRoute(value) {
  const match = /^(.*?) — tournée de distribution (10|[1-9])$/.exec(value || '');
  return match ? { agency: match[1], tournee: Number(match[2]) } : { agency: value, tournee: null };
}

export function missingCountAgencies(month, submissions) {
  const dates = templateDates(month);
  const byAgency = new Map(COUNT_AGENCIES.map(agency => [agency, []]));
  for (const entry of submissions) {
    const identity = splitCountAgencyRoute(entry.agency);
    const records = byAgency.get(identity.agency);
    if (records) records.push({ entry, tournee: identity.tournee });
  }
  return COUNT_AGENCIES.map(agency => {
    const received = byAgency.get(agency);
    const routes = received.length
      ? received.map(({entry, tournee}) => {
          // 0 is a valid, actually entered number; an entirely empty row is not.
          const sent = new Set((entry.rows || []).filter(row => Array.isArray(row.values) &&
            row.values.some(value => value !== null && value !== undefined)).map(row => row.date));
          return { tournee, missing: dates.filter(date => !sent.has(date)) };
        }).filter(route => route.missing.length > 0)
      : [{tournee: null, missing: [...dates]}];
    return { agency, received: received.length, routes, missingCount: routes.reduce((sum,route) => sum + route.missing.length, 0) };
  }).filter(item => item.routes.length > 0);
}
