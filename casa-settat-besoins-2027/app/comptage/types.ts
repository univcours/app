export type CountRow = { date: string; frequency: number | null; values: (number | null)[] };
export type CountDraft = Record<string, { frequency: string; values: string[] }>;
export type CountSubmission = { id: string; agency: string; month: string; rows: CountRow[]; createdAt: string; updatedAt: string };
