-- Create expenses table for financial tracking
CREATE TABLE IF NOT EXISTS expenses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  amount DECIMAL(10, 2) NOT NULL,
  date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  category VARCHAR(50) NOT NULL,
  animal_id UUID REFERENCES animals(id) ON DELETE SET NULL,
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
  vendor_name VARCHAR(255),
  receipt_url TEXT,
  tags TEXT[],
  payment_method VARCHAR(50) DEFAULT 'cash',
  is_recurring BOOLEAN DEFAULT FALSE,
  recurring_frequency VARCHAR(50),
  next_due_date TIMESTAMP WITH TIME ZONE,
  is_paid BOOLEAN DEFAULT TRUE,
  paid_date TIMESTAMP WITH TIME ZONE,
  notes TEXT,
  journal_entry_id UUID,
  invoice_number VARCHAR(100),
  tax_amount DECIMAL(10, 2),
  budget_category VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX idx_expenses_user_id ON expenses(user_id);
CREATE INDEX idx_expenses_date ON expenses(date DESC);
CREATE INDEX idx_expenses_animal_id ON expenses(animal_id);
CREATE INDEX idx_expenses_category ON expenses(category);
CREATE INDEX idx_expenses_is_paid ON expenses(is_paid);
CREATE INDEX idx_expenses_user_date ON expenses(user_id, date DESC);

-- Enable Row Level Security (RLS)
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own expenses"
  ON expenses FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own expenses"
  ON expenses FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own expenses"
  ON expenses FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own expenses"
  ON expenses FOR DELETE
  USING (auth.uid() = user_id);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_expenses_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update updated_at
CREATE TRIGGER expenses_updated_at
  BEFORE UPDATE ON expenses
  FOR EACH ROW
  EXECUTE FUNCTION update_expenses_updated_at();

-- Create view for expense statistics
CREATE OR REPLACE VIEW expense_statistics AS
SELECT
  user_id,
  DATE_TRUNC('month', date) AS month,
  COUNT(*) AS transaction_count,
  SUM(amount) AS total_amount,
  SUM(CASE WHEN is_paid THEN amount ELSE 0 END) AS paid_amount,
  SUM(CASE WHEN NOT is_paid THEN amount ELSE 0 END) AS unpaid_amount,
  AVG(amount) AS average_amount,
  COUNT(DISTINCT category) AS category_count,
  COUNT(DISTINCT animal_id) AS animal_count
FROM expenses
GROUP BY user_id, DATE_TRUNC('month', date);

-- Grant permissions on the view
GRANT SELECT ON expense_statistics TO authenticated;

-- Create function to get expense summary for a user
CREATE OR REPLACE FUNCTION get_expense_summary(
  p_user_id UUID,
  p_start_date TIMESTAMP WITH TIME ZONE DEFAULT NULL,
  p_end_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS TABLE (
  total_amount DECIMAL,
  paid_amount DECIMAL,
  unpaid_amount DECIMAL,
  transaction_count INTEGER,
  average_amount DECIMAL,
  top_category VARCHAR,
  top_category_amount DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  WITH expense_data AS (
    SELECT
      e.amount,
      e.is_paid,
      e.category
    FROM expenses e
    WHERE e.user_id = p_user_id
      AND (p_start_date IS NULL OR e.date >= p_start_date)
      AND (p_end_date IS NULL OR e.date <= p_end_date)
  ),
  category_totals AS (
    SELECT
      category,
      SUM(amount) AS category_total
    FROM expense_data
    GROUP BY category
    ORDER BY category_total DESC
    LIMIT 1
  )
  SELECT
    COALESCE(SUM(ed.amount), 0)::DECIMAL AS total_amount,
    COALESCE(SUM(CASE WHEN ed.is_paid THEN ed.amount ELSE 0 END), 0)::DECIMAL AS paid_amount,
    COALESCE(SUM(CASE WHEN NOT ed.is_paid THEN ed.amount ELSE 0 END), 0)::DECIMAL AS unpaid_amount,
    COUNT(*)::INTEGER AS transaction_count,
    COALESCE(AVG(ed.amount), 0)::DECIMAL AS average_amount,
    ct.category AS top_category,
    ct.category_total AS top_category_amount
  FROM expense_data ed
  CROSS JOIN category_totals ct;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to link expense to journal entry
CREATE OR REPLACE FUNCTION link_expense_to_journal(
  p_expense_id UUID,
  p_journal_entry_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  v_user_id UUID;
BEGIN
  -- Get the user_id from the expense
  SELECT user_id INTO v_user_id
  FROM expenses
  WHERE id = p_expense_id;
  
  -- Verify ownership and update
  UPDATE expenses
  SET journal_entry_id = p_journal_entry_id
  WHERE id = p_expense_id
    AND user_id = v_user_id
    AND user_id = auth.uid();
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Sample expense categories for reference
COMMENT ON COLUMN expenses.category IS 'Categories: feed, health_veterinary, equipment, transportation, show_entry, supplies, housing, breeding, processing, marketing, utilities, insurance, registration, training, other';

-- Sample payment methods for reference
COMMENT ON COLUMN expenses.payment_method IS 'Payment methods: cash, check, credit_card, debit_card, bank_transfer, grant, scholarship, fundraising, sponsor, other';

-- Add constraint to ensure amount is positive
ALTER TABLE expenses ADD CONSTRAINT expenses_amount_positive CHECK (amount >= 0);

-- Add constraint to ensure tax_amount is not negative
ALTER TABLE expenses ADD CONSTRAINT expenses_tax_amount_non_negative CHECK (tax_amount IS NULL OR tax_amount >= 0);