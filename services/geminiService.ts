import { GoogleGenAI, Type } from "@google/genai";
import { Category } from '../types';

if (!process.env.API_KEY) {
  // A mock key is provided for development, replace with a real key in a .env file for production.
  // This helps prevent the app from crashing if the key is not set.
  process.env.API_KEY = "MOCK_API_KEY_REPLACE_ME";
}

const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

const base64FromFile = (file: File): Promise<string> =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.readAsDataURL(file);
    reader.onload = () => resolve((reader.result as string).split(',')[1]);
    reader.onerror = (error) => reject(error);
  });
  
export const scanReceipt = async (imageFile: File, categories: Category[]) => {
  try {
    const base64Image = await base64FromFile(imageFile);
    const categoryNames = categories.map(c => c.name).join(', ');

    const response = await ai.models.generateContent({
      model: 'gemini-2.5-flash',
      contents: {
          parts: [
              {
                  inlineData: {
                    mimeType: imageFile.type,
                    data: base64Image,
                  },
              },
              {
                  text: `Analyze this receipt. Extract the total amount, the date (in YYYY-MM-DD format), and a concise name for the expense (e.g., 'Groceries at Store Name', 'Dinner at whichever restaurant name provided in receipt'). From the list of available categories [${categoryNames}], select the most appropriate one for this expense. If any field cannot be determined, use a sensible default.`,
              },
          ],
      },
      config: {
        responseMimeType: 'application/json',
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            name: {
              type: Type.STRING,
              description: 'A short, descriptive name for the expense (e.g., "Groceries at Walmart (based on receipt)").',
            },
            amount: {
              type: Type.NUMBER,
              description: 'The total amount of the expense.',
            },
            date: {
              type: Type.STRING,
              description: 'The date of the transaction in YYYY-MM-DD format.',
            },
            categoryName: {
              type: Type.STRING,
              description: `The most fitting category from the provided list: [${categoryNames}].`,
            },
          },
          required: ['name', 'amount', 'date', 'categoryName'],
        },
      },
    });

    const jsonText = response.text.trim();
    return JSON.parse(jsonText);
  } catch (error) {
    console.error("Error scanning receipt with Gemini API:", error);
    // Provide a more user-friendly error message
    if(process.env.API_KEY === "MOCK_API_KEY_REPLACE_ME") {
        alert("Scanning requires a valid Gemini API key. Please configure it to use this feature.");
    } else {
        alert("Failed to scan receipt. The AI model could not process the image. Please try again or enter the details manually.");
    }
    return null;
  }
};